local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local Players: Players = cloneref(game:GetService("Players"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService: RunService = cloneref(game:GetService("RunService"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local PredictionLib = vape.Libraries.prediction

local Soccer = {}
local Movement = {Direction = nil, Facing = nil, Expiry = 0}
local PassHold: number = 0
local KeepHold: number = 0
local CenterHold: number = 0

local function GetBall()
    local BallId = Soccer.Renderer.GetMatchBallId()
    local State = BallId and Soccer.Renderer.GetAuthoritativeMovementState() or nil
    if State then
        return BallId, State
    end

    local Closest, Distance = nil, math.huge
    local LocalPosition: Vector3 = Entity.isAlive and Entity.character.RootPart.Position or Camera.CFrame.Position
    for _, v: BasePart in workspace.Misc.Visuals:GetChildren() do
        local Id: string? = v.Name:match("^ClientBall_(.+)$")
        if Id then
            local Magnitude: number = (v.Position - LocalPosition).Magnitude
            if Magnitude < Distance then
                Closest, Distance = Id, Magnitude
            end
        end
    end

    return Closest, Closest and Soccer.Renderer.GetMovementState(Closest) or nil
end

local function GetOwnedPosition(): Vector3?
    if not Entity.isAlive then
        return nil
    end

    local Position: Vector3? = Soccer.Carry.GetVisualOwnedPosition(Entity.character.Character)
    return Position or Entity.character.RootPart.Position
end

local function GetIntercept(State, Horizon: number, Range: number)
    local Humanoid: Humanoid = Entity.character.Humanoid
    local LocalPosition: Vector3 = Entity.character.RootPart.Position
    local Reach: number = Soccer.HitboxSettings.Receive.Size.Y * 0.5
    local AirReach: number = Soccer.HitboxSettings.AirReceive.Size.Y * 0.5 + Humanoid.JumpHeight
    local Closest, Approach = math.huge, nil
    for i: number = 1, 60 do
        local Step: number = i * (Horizon / 60)
        local Position: Vector3 = Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, Step)
        local Rise: number = Position.Y - LocalPosition.Y
        local Flat: number = ((Position - LocalPosition) * Vector3.new(1, 0, 1)).Magnitude
        if Flat < Closest and Flat <= Range then
            Closest, Approach = Flat, Position
        end
        if Flat <= math.min(Range, Humanoid.WalkSpeed * Step + 2) and Rise <= AirReach and Rise >= -Reach then
            return Step, Position, Rise > Reach
        end
    end

    return nil, Approach
end

local function GetGoal(Enemy: boolean)
    local Team: string? = Soccer.ActorTeams.GetActorTeamName(LocalPlayer)
    if not Team then
        return nil
    end

    local Side: Instance? = workspace.Map.Data:FindFirstChild(Enemy and (Team == "Team1" and "Team2" or "Team1") or Team)
    return Side and Side:FindFirstChild("Goal") or nil
end

local function GetInput(Action: string)
    local Bind = Soccer.Keybinds.Get(Action)
    if not Bind then
        return nil
    end

    return {
        KeyCode = Bind.KeyCodes and Bind.KeyCodes[1] or Enum.KeyCode.Unknown,
        UserInputType = Bind.InputTypes and Bind.InputTypes[1] or Enum.UserInputType.Keyboard,
        UserInputState = Enum.UserInputState.Begin
    }
end

local function HoldPasses(Seconds: number)
    PassHold = os.clock() + Seconds
end

local function IsPassHeld(): boolean
    return os.clock() < PassHold
end

local function HoldKeeping(Seconds: number)
    KeepHold = os.clock() + Seconds
end

local function IsKeepingHeld(): boolean
    return os.clock() < KeepHold
end

local function HoldCenter(Seconds: number)
    CenterHold = os.clock() + Seconds
end

local function IsCenterHeld(): boolean
    return os.clock() < CenterHold
end

local function MoveCharacter(Direction: Vector3, Facing: Vector3?)
    if not Entity.isAlive then
        return
    end

    Movement.Direction = Direction
    Movement.Facing = Facing or (Direction.Magnitude > 0.01 and Direction or nil)
    Movement.Expiry = os.clock() + 0.2
    Soccer.Controllers.SetMoveCommand(Entity.character.Character, Direction, Movement.Facing, false)
end

local function StopCharacter()
    if not Movement.Direction then
        return
    end

    Movement.Direction, Movement.Facing, Movement.Expiry = nil, nil, 0
    if Entity.isAlive then
        Soccer.Controllers.SetMoveCommand(Entity.character.Character, Vector3.zero, nil, false)
    end
end

local function GetKeeper(Goal: BasePart)
    local Closest, Distance = nil, math.huge
    for _, v: any in Entity.List do
        local Magnitude: number = v.Targetable and (v.RootPart.Position - Goal.Position).Magnitude or math.huge
        if Magnitude <= 150 then
            if v.Character:GetAttribute("ActiveGoalkeeper") then
                return v
            end
            
            if Magnitude < Distance then
                Closest, Distance = v, Magnitude
            end
        end
    end

    return Distance < 45 and Closest or nil
end

local function GetCarrier()
    local UserId: number? = Soccer.Renderer.GetMainMatchOwnerUserId()
    if not UserId then
        return nil
    end

    for _, v: any in Entity.List do
        if (v.Player and v.Player.UserId or v.Character:GetAttribute("UserId")) == UserId then
            return v
        end
    end

    return nil
end

Run(function()
    Soccer = {
        ActionCommands = require(ReplicatedStorage.Modules.Actions.ActionCommands),
        ActionMotion = require(ReplicatedStorage.Modules.Actions.ActionMotion),
        ActionRemoteProtocol = require(ReplicatedStorage.Modules.Actions.ActionRemoteProtocol),
        ActorTeams = require(ReplicatedStorage.Client.Gameplay.ActorTeams),
        Aim = require(ReplicatedStorage.Client.Gameplay.Actions.Aim),
        AimFacing = require(ReplicatedStorage.Modules.Actions.AimFacing),
        ChargePathPreview = require(ReplicatedStorage.Client.Gameplay.Actions.ChargePathPreview),
        ChargePathVelocity = require(ReplicatedStorage.Modules.Actions.ChargePathVelocity),
        AssistedPass = require(ReplicatedStorage.Modules.Actions.AssistedPass),
        CameraBallSnap = require(ReplicatedStorage.Client.Gameplay.Player.CameraBallSnap),
        CallForPass = require(ReplicatedStorage.Client.Gameplay.Actions.CallForPass),
        Carry = require(ReplicatedStorage.Modules.Ball.Carry),
        Catalog = require(ReplicatedStorage.Modules.Cosmetics.Catalog),
        Controllers = require(ReplicatedStorage.Modules.Characters.CharacterControllers),
        Controls = require(ReplicatedStorage.Modules.Gameplay.Controls),
        CurvedKicks = require(ReplicatedStorage.Modules.CurvedKicks),
        Dodge = require(ReplicatedStorage.Modules.Actions.Dodge),
        DodgeInput = require(ReplicatedStorage.Client.Gameplay.Actions.Dodge),
        GoalEffect = require(ReplicatedStorage.Client.Gameplay.Visual.GoalEffect),
        GoalkeeperActions = require(ReplicatedStorage.Modules.Actions.GoalkeeperActions),
        GoalkeeperDive = require(ReplicatedStorage.Modules.Actions.GoalkeeperDive),
        GoalkeeperPositioning = require(ReplicatedStorage.Modules.Gameplay.GoalkeeperPositioning),
        GoalkeeperPrediction = require(ReplicatedStorage.Modules.Gameplay.GoalkeeperPrediction),
        GoalkeeperRole = require(ReplicatedStorage.Client.Gameplay.Player.GoalkeeperRole),
        HitboxSettings = require(ReplicatedStorage.Modules.Gameplay.HitboxSettings),
        ItemIds = require(ReplicatedStorage.Modules.Items.ItemIds),
        ItemUseState = require(ReplicatedStorage.Client.Gameplay.ItemUseState),
        Keybinds = require(ReplicatedStorage.Modules.Gameplay.Keybinds),
        Kick = require(ReplicatedStorage.Modules.Actions.Kick),
        KickCore = require(ReplicatedStorage.Modules.Actions.KickCore),
        KickoffFreeze = require(ReplicatedStorage.Client.Gameplay.KickoffFreeze),
        Lobby = require(ReplicatedStorage.Client.Environment.LobbyVisibility),
        MatchSettings = require(ReplicatedStorage.Modules.Gameplay.MatchSettings),
        MovementActivity = require(ReplicatedStorage.Client.Player.MovementActivity),
        OilSpill = require(ReplicatedStorage.Modules.Items.OilSpill),
        Ownership = require(ReplicatedStorage.Modules.Ball.Ownership),
        Pass = require(ReplicatedStorage.Modules.Actions.Pass),
        PassInput = require(ReplicatedStorage.Client.Gameplay.Actions.Pass),
        Physics = require(ReplicatedStorage.Modules.Ball.Physics),
        PlayerSettings = require(ReplicatedStorage.Modules.PlayerSettings),
        Ragdoll = require(ReplicatedStorage.Modules.Characters.Ragdoll),
        RankedState = require(ReplicatedStorage.Client.Interface.RankedState),
        Remotes = require(ReplicatedStorage.Modules.Remotes),
        Renderer = require(ReplicatedStorage.Client.Gameplay.Ball.Renderer),
        Reticle = require(ReplicatedStorage.Client.Interface.Reticle),
        Shoot = require(ReplicatedStorage.Modules.Actions.Shoot),
        ShootInput = require(ReplicatedStorage.Client.Gameplay.Actions.Shoot),
        SlideTackle = require(ReplicatedStorage.Modules.Actions.SlideTackle),
        SlideTackleInput = require(ReplicatedStorage.Client.Gameplay.Actions.SlideTackleInput),
        Sprint = require(ReplicatedStorage.Modules.Actions.Sprint),
        SprintInput = require(ReplicatedStorage.Client.Gameplay.Player.Sprint),
        TeamJoinPlatforms = require(ReplicatedStorage.Modules.Gameplay.TeamJoinPlatforms),
        TurnControl = require(ReplicatedStorage.Client.Gameplay.Player.TurnControl),
        VolleyLockOn = require(ReplicatedStorage.Modules.Ball.VolleyLockOn),
        VolleyOpportunity = require(ReplicatedStorage.Client.Gameplay.Actions.VolleyOpportunity)
    }

    vape:Clean(function()
        table.clear(Soccer)
    end)
end)

Run(function()
    local Controllers = Soccer.Controllers
    local Old: (...any) -> ...any = Controllers.GetMoveCommand
    local Hook = function(Character: Model)
        if Character == LocalPlayer.Character and Movement.Direction and os.clock() < Movement.Expiry then
            return Movement.Direction
        end
        return Old(Character)
    end
    Controllers.GetMoveCommand = Hook

    vape:Clean(function()
        if Controllers.GetMoveCommand == Hook then
            Controllers.GetMoveCommand = Old
        end
    end)
end)

Run(function()
    local OldCheck, OldColor = Entity.targetCheck, Entity.getEntityColor
    Entity.targetCheck = function(Ent)
        local Team: string? = Soccer.ActorTeams.GetActorTeamName(LocalPlayer)
        if Team and Soccer.ActorTeams.GetCharacterTeamName(Ent.Character) == Team then
            return false
        end
        return OldCheck(Ent)
    end

    Entity.getEntityColor = function(Ent)
        local Call: Color3? = OldColor(Ent)
        if Call or not vape.Settings.Modules.Options["Use team color"].Enabled then
            return Call
        end
        return Soccer.ActorTeams.GetCharacterTeamName(Ent.Character) == "Team1" and Color3.new(0.3, 0.55, 1) or Color3.new(1, 0.35, 0.35)
    end

    local OldStart: (...any) -> ...any = Entity.start
    Entity.start = function()
        OldStart()
        if Entity.Running then
            for _, v: Model in workspace.Characters.NPCs:GetChildren() do
                Entity.addEntity(v)
            end
            
            table.insert(Entity.Connections, workspace.Characters.NPCs.ChildAdded:Connect(Entity.addEntity))
            table.insert(Entity.Connections, workspace.Characters.NPCs.ChildRemoved:Connect(Entity.removeEntity))
            table.insert(Entity.Connections, ReplicatedStorage.Remotes.Match.State.OnClientEvent:Connect(function()
                task.delay(0.1, Entity.refresh)
            end))
        end
    end
end)
Entity.start()

for _, v: string in {"AimAssist", "Reach", "SilentAim", "TriggerBot", "Killaura", "MurderMystery", "AntiRagdoll", "Disabler", "PromptChanger", "Jesus", "Xray"} do
    vape:Remove(v)
end

Run(function()
	local Sprint
	local WithBall
	
	Sprint = vape.Categories.Combat:CreateModule({
	    Name = "Sprint",
	    Function = function(Callback: boolean)
	        if Callback then
	            Sprint:Clean(RunService.Heartbeat:Connect(function()
	                if not Entity.isAlive then
	                    return
	                end
	
	                local Wanted: boolean = not WithBall.Enabled or Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) ~= nil
	                if Wanted == Soccer.SprintInput.IsSprintButtonToggled() then
	                    return
	                end
	                if Wanted and not Soccer.SprintInput.IsSprintButtonUsable() then
	                    return
	                end
	
	                Soccer.SprintInput.ToggleSprintButton()
	            end))
	        elseif Soccer.SprintInput.IsSprintButtonToggled() then
	            Soccer.SprintInput.ToggleSprintButton()
	        end
	    end,
	    Tooltip = "Keeps you sprinting without holding the key down."
	})
	
	WithBall = Sprint:CreateToggle({
	    Name = "Only with ball",
	    Tooltip = "Only sprints while you are the one carrying the ball."
	})
end)

Run(function()
	local PerfectShot
	local Passes
	
	local OldKick, OldAlpha
	local HookKick, HookAlpha
	
	PerfectShot = vape.Categories.Combat:CreateModule({
	    Name = "PerfectShot",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not HookKick then
	                OldKick = Soccer.ActionCommands.Kick
	                HookKick = function(Command)
	                    local Call = OldKick(Command)
	                    if PerfectShot.Enabled and Call and Call.ChargeSeconds and Call.MaximumChargeSeconds and (Passes.Enabled or Call.PassType == Soccer.ActionCommands.PassTypes.Shot) then
	                        Call.ChargeSeconds = Call.MaximumChargeSeconds
	                    end
	                    return Call
	                end
	                Soccer.ActionCommands.Kick = HookKick
	            end
	
	            if not HookAlpha then
	                OldAlpha = Soccer.KickCore.GetChargeAlpha
	                HookAlpha = function(Seconds: number, Constants)
	                    if PerfectShot.Enabled and (Passes.Enabled or not Constants or Constants == Soccer.KickCore.Constants) then
	                        return 1
	                    end
	                    return OldAlpha(Seconds, Constants)
	                end
	                Soccer.KickCore.GetChargeAlpha = HookAlpha
	            end
	        else
	            if Soccer.ActionCommands.Kick == HookKick then
	                Soccer.ActionCommands.Kick = OldKick
	                HookKick = nil
	            end
	            if Soccer.KickCore.GetChargeAlpha == HookAlpha then
	                Soccer.KickCore.GetChargeAlpha = OldAlpha
	                HookAlpha = nil
	            end
	        end
	    end,
	    Tooltip = "Sends every shot at full power without holding the charge."
	})
	
	Passes = PerfectShot:CreateToggle({
	    Name = "Passes",
	    Tooltip = "Puts passes, lobs and throws on full power too."
	})
end)

Run(function()
	local ShotRedirect
	local Mode
	local Height
	local Fake
	local PerfectFake
	local Switch
	local MaxAngle
	local Range
	local BodyAim
	local AutoAim
	local AimSpeed
	local Display
	local AutoCurve
	local CurveAmount
	
	local FlatMask: Vector3 = Vector3.new(1, 0, 1)
	local SideInset: number = 7
	local EdgeMargin: number = 0.75
	local MoveConstant: Vector2 = Vector2.new(1, 0.77) * math.rad(0.5)
	local Randomizer: Random = Random.new()
	local Roll, WasCharging, ChargeStart, LockedAim
	local Holds: {number} = {}
	local Solved = {}
	local Reached = {}
	local CurveSolved = {}
	local Flight = {}
	local Lifts: {number} = {6, 12, 24}
	local ShotCurve: number?
	local CurveLocked: boolean = false
	local Old, OldAim, OldCommand, OldLock, OldEnded
	local HookAim, HookRay, HookCommand, HookLock, HookEnded
	local Marker: Part?
	local AimPoint: Vector3?
	
	local function GetSwitch(): number
	    if not PerfectFake.Enabled then
	        return Switch.Value
	    end
	
	    local Shortest: number = Soccer.KickCore.Constants.MaximumChargeSeconds
	    for _, v: number in Holds do
	        if v < Shortest then
	            Shortest = v
	        end
	    end
	
	    return math.max(Shortest - 0.06, 0.05)
	end
	
	local function GetCharge(): number
	    return ChargeStart and math.clamp(os.clock() - ChargeStart, 0, Soccer.KickCore.Constants.MaximumChargeSeconds) or Soccer.KickCore.Constants.MaximumChargeSeconds
	end
	
	local function GetAimCharge(): number
	    return Soccer.KickCore.Constants.MaximumChargeSeconds
	end
	
	local function GetEdge(Margin: number?): number
	    return Soccer.Physics.BallRadius + (Margin or EdgeMargin)
	end
	
	local function GetTop(Goal: BasePart): number
	    return 1 - GetEdge() / Goal.Size.Y
	end
	
	local function GetLaunchOrigin(): Vector3?
	    if not Entity.isAlive then
	        return nil
	    end
	
	    return Soccer.Carry.GetLaunchPosition and Soccer.Carry.GetLaunchPosition(Entity.character.Character) or GetOwnedPosition()
	end
	
	local function SetNativeCurve(Value: number?)
	    local Success, Current = pcall(debug.getupvalue, Soccer.ShootInput.HandleInputBegan, 7)
	    if Success and typeof(Current) == "number" then
	        pcall(debug.setupvalue, Soccer.ShootInput.HandleInputBegan, 7, Value or 0)
	    end
	end
	
	local function GetCurveDirection(Side: number, Normal: Vector3, Goal: BasePart): number?
	    if math.abs(Side) < 0.05 then
	        return nil
	    end
	
	    return math.sign(Side) * math.sign(Normal:Dot(Goal.CFrame.LookVector))
	end
	
	local function GetReported(): Vector3
	    local Velocity: Vector3 = Entity.isAlive and Entity.character.RootPart.AssemblyLinearVelocity or Vector3.zero
	    return Vector3.new(Velocity.X, 0, Velocity.Z)
	end
	
	local function GetAimRay(Call, Direction: Vector3)
	    return {
	        Origin = Call.Origin,
	        CameraCFrame = CFrame.lookAt(Call.Origin, Call.Origin + Direction),
	        IsAirborne = Call.IsAirborne,
	        Direction = Direction
	    }
	end
	
	local function GetLaunch(Origin: Vector3, Call, Direction: Vector3, Curve: number?, Charge: number?): Vector3?
	    local AimRay = GetAimRay(Call, Direction)
	    local Success, Velocity = pcall(Soccer.ChargePathVelocity.Get, Entity.character.Character, Charge or GetCharge(), Soccer.ActionCommands.PassTypes.Shot, AimRay, Origin, GetReported(), Soccer.AimFacing.GetFlatDirection(Direction), nil, Soccer.ChargePathPreview.GetChargeBoundaryWorld(LocalPlayer), Curve)
	
	    return Success and typeof(Velocity) == "Vector3" and Velocity or nil
	end
	
	local function GetCrossing(Origin: Vector3, Velocity: Vector3, Plane: number, Normal: Vector3, Charge: number?)
	    local Closing: number = (Velocity * FlatMask):Dot(Normal)
	    if Closing < 1 then
	        return nil
	    end
	
	    local Spun, Spin = pcall(Soccer.Shoot.GetSpin, Entity.character.Character, Velocity, GetReported(), nil, Charge or GetCharge())
	    local Started: number = workspace:GetServerTimeNow()
	    local Built, State = pcall(Soccer.Physics.NewState, Origin, Velocity, Soccer.Physics.BallRadius, Started, Spun and Spin or Vector3.new(0, 0, 0), Flight)
	    local Boundary = Soccer.Renderer.GetMatchBoundaryWorld()
	    if not Built or not State or not Boundary then
	        return nil
	    end
	
	    local Previous, Covered = Origin, 0
	    local Nearest, NearestGap = nil, math.huge
	    local Moving: Vector3 = Velocity
	    local Gravity: Vector3 = Vector3.new(0, Soccer.Physics.Constants.Air.Gravity.Y, 0)
	    for i: number = 1, 60 do
	        local Stepped, Result = pcall(Soccer.Physics.GetStateAtTime, State, Started + i * 0.03, Boundary, State)
	        local Position = Stepped and Result and Result.Position or nil
	        if typeof(Position) ~= "Vector3" then
	            break
	        end
	
	        local CurrentVelocity: Vector3 = typeof(Result.Velocity) == "Vector3" and Result.Velocity or Moving
	        if (CurrentVelocity - Moving - Gravity * 0.03).Magnitude > 6 then
	            local Speed: number = (Moving * FlatMask):Dot(Normal)
	            if Speed < 1 then
	                break
	            end
	
	            local FlightTime: number = (Plane - Covered) / Speed
	            return Previous + Moving * FlightTime + Gravity * (0.5 * FlightTime * FlightTime), (i - 1) * 0.03 + FlightTime
	        end
	        Moving = CurrentVelocity
	
	        local Travelled: number = (Position - Origin):Dot(Normal)
	        if Travelled >= Plane then
	            local Span: number = Travelled - Covered
	            local Alpha: number = Span > 0.001 and (Plane - Covered) / Span or 0
	            return Previous:Lerp(Position, Alpha), (i - 1 + Alpha) * 0.03
	        end
	
	        local Gap: number = Plane - Travelled
	        if Gap < NearestGap then
	            Nearest, NearestGap = Position, Gap
	        end
	        Previous, Covered = Position, Travelled
	    end
	
	    if Nearest and NearestGap <= 4 then
	        return Nearest, nil
	    end
	
	    return nil
	end
	
	local function GetArrival(Origin: Vector3, Call, Target: Vector3, Plane: number, Normal: Vector3, Charge: number?)
	    local Offset: Vector3 = Target - Call.Origin
	    if Offset.Magnitude < 0.01 then
	        return nil
	    end
	
	    local Direction: Vector3 = Offset.Unit
	    local Velocity: Vector3? = GetLaunch(Origin, Call, Direction, nil, Charge)
	    if not Velocity then
	        return nil
	    end
	
	    local Point, Travel = GetCrossing(Origin, Velocity, Plane, Normal, Charge)
	    return Point, Direction, Travel
	end
	
	local function GetDirection(Origin: Vector3, Call, Aim: Vector3, Normal: Vector3, Charge: number?)
	    local Offset: Vector3 = (Aim - Origin) * FlatMask
	    local Plane: number = Offset:Dot(Normal)
	    if Offset.Magnitude < 0.01 or Plane < 0.01 then
	        return nil
	    end
	
	    Charge = Charge or GetAimCharge()
	    local Now: number = os.clock()
	    local Reported: Vector3 = GetReported()
	
	    local Warm, Nearest, Reuse = nil, math.huge, false
	    for _, v: any in Solved do
	        local Distance: number = (v.Aim - Aim).Magnitude
	        if v.Normal == Normal and Distance < 4 then
	            local Moved: number = (v.Origin - Origin).Magnitude
	            local Matched: boolean = math.abs(v.Charge - Charge) < 0.001
	            if Matched and Distance < 0.2 and Moved < 0.2 and Now - v.Time < 0.05
	                and v.Airborne == Call.IsAirborne and (v.Reported - Reported).Magnitude < 0.5 then
	                return v.Direction, v.Point, v.Travel
	            end
	            local Score: number = Distance + Moved + (Matched and 0 or 2)
	            if Score < Nearest then
	                Warm, Nearest, Reuse = v, Score, Matched and Distance < 1 and Moved < 0.5
	            end
	        end
	    end
	
	    local Lateral: Vector3 = Vector3.new(-Normal.Z, 0, Normal.X)
	    local WantHeight, WantSide = Aim.Y, Aim:Dot(Lateral)
	    local Passes: number = 0
	    local function Measure(Lift: number, Shift: number)
	        Passes += 1
	        local Point, Direction, Travel = GetArrival(Origin, Call, Aim + Vector3.new(0, Lift, 0) + Lateral * Shift, Plane, Normal, Charge)
	        if not Point then
	            return nil
	        end
	
	        local Side: number = Point:Dot(Lateral)
	        return {
	            Lift = Lift,
	            Shift = Shift,
	            Height = Point.Y,
	            Side = Side,
	            Point = Point,
	            Direction = Direction,
	            Travel = Travel,
	            Gap = math.max(math.abs(WantHeight - Point.Y), math.abs(WantSide - Side))
	        }
	    end
	
	    local Best = Measure(Warm and Warm.Lift or 0, Warm and Warm.Shift or 0)
	    if not Best then
	        return nil
	    end
	
	    local Slopes, Fresh = Warm and Warm.Slopes or nil, false
	    local Scale: number = 1
	    while Best.Gap >= 0.05 and Passes < 12 do
	        if not Slopes then
	            local Up, Across = Measure(Best.Lift + 0.5, Best.Shift), Measure(Best.Lift, Best.Shift + 0.5)
	            if not (Up and Across) then
	                break
	            end
	
	            Slopes = {(Up.Height - Best.Height) / 0.5, (Across.Height - Best.Height) / 0.5, (Up.Side - Best.Side) / 0.5, (Across.Side - Best.Side) / 0.5}
	            Fresh, Scale = true, 1
	        end
	
	        local A, B, C, D = Slopes[1], Slopes[2], Slopes[3], Slopes[4]
	        local Determinant: number = A * D - B * C
	        if math.abs(Determinant) < 0.001 then
	            break
	        end
	
	        local GapHeight, GapSide = WantHeight - Best.Height, WantSide - Best.Side
	        local Lift: number = math.clamp(Best.Lift + math.clamp((D * GapHeight - B * GapSide) / Determinant, -25, 25) * Scale, -60, 60)
	        local Shift: number = math.clamp(Best.Shift + math.clamp((A * GapSide - C * GapHeight) / Determinant, -40, 40) * Scale, -80, 80)
	        local NextBest = Measure(Lift, Shift)
	        if not NextBest then
	            break
	        end
	
	        if NextBest.Gap < Best.Gap then
	            local DeltaLift, DeltaShift = Lift - Best.Lift, Shift - Best.Shift
	            local Norm: number = DeltaLift * DeltaLift + DeltaShift * DeltaShift
	            if Norm > 1e-6 then
	                local MissHeight: number = NextBest.Height - Best.Height - (A * DeltaLift + B * DeltaShift)
	                local MissSide: number = NextBest.Side - Best.Side - (C * DeltaLift + D * DeltaShift)
	                Slopes = {A + MissHeight * DeltaLift / Norm, B + MissHeight * DeltaShift / Norm, C + MissSide * DeltaLift / Norm, D + MissSide * DeltaShift / Norm}
	            end
	            Best, Fresh, Scale = NextBest, false, 1
	        elseif Fresh then
	            Scale *= 0.5
	        else
	            Slopes = nil
	        end
	    end
	
	    local Entry = Reuse and Warm or nil
	    if not Entry then
	        Entry = {}
	        if #Solved < 12 then
	            table.insert(Solved, Entry)
	        else
	            local Oldest: number = 1
	            for i: number, v: any in Solved do
	                if v.Time < Solved[Oldest].Time then
	                    Oldest = i
	                end
	            end
	            Solved[Oldest] = Entry
	        end
	    end
	
	    Entry.Direction, Entry.Point, Entry.Travel, Entry.Time = Best.Direction, Best.Point, Best.Travel, Now
	    Entry.Lift, Entry.Shift, Entry.Slopes = Best.Lift, Best.Shift, Slopes
	    Entry.Origin, Entry.Aim, Entry.Charge, Entry.Normal = Origin, Aim, Charge, Normal
	    Entry.Reported, Entry.Airborne = Reported, Call.IsAirborne
	
	    return Best.Direction, Best.Point, Best.Travel
	end
	
	local function GetReach(Origin: Vector3, Call, Aim: Vector3, Normal: Vector3, Charge: number): number?
	    local Now: number = os.clock()
	    if Reached.Time and Now - Reached.Time < 0.1 and Reached.Charge == Charge and (Reached.Origin - Origin).Magnitude < 0.5 and (Reached.Aim - Aim).Magnitude < 0.5 then
	        return Reached.Height
	    end
	
	    local Plane: number = ((Aim - Origin) * FlatMask):Dot(Normal)
	    local BestHeight: number?
	    if Plane > 0.01 then
	        for _, Lift: number in Lifts do
	            local Point = GetArrival(Origin, Call, Aim + Vector3.new(0, Lift, 0), Plane, Normal, Charge)
	            if Point and (not BestHeight or Point.Y > BestHeight) then
	                BestHeight = Point.Y
	                if BestHeight >= Aim.Y + 1 then
	                    break
	                end
	            end
	        end
	    end
	    Reached.Height, Reached.Time, Reached.Origin, Reached.Aim, Reached.Charge = BestHeight, Now, Origin, Aim, Charge
	
	    return BestHeight
	end
	
	local function GetCurvedLanding(Origin: Vector3, Velocity: Vector3, Curve: number, Charge: number, Plane: number, Normal: Vector3, Boundary): Vector3?
	    local Spun, Spin = pcall(Soccer.Shoot.GetSpin, Entity.character.Character, Velocity, GetReported(), Curve, Charge)
	    if not Spun or typeof(Spin) ~= "Vector3" then
	        return nil
	    end
	
	    local Started: number = workspace:GetServerTimeNow()
	    local Built, State = pcall(Soccer.Physics.NewState, Origin, Velocity, Soccer.Physics.BallRadius, Started, Spin, Flight)
	    if not Built or not State then
	        return nil
	    end
	
	    local Previous, Covered = Origin, 0
	    for i: number = 1, 90 do
	        local Stepped, Result = pcall(Soccer.Physics.GetStateAtTime, State, Started + i * 0.03, Boundary, State)
	        local Position = Stepped and Result and Result.Position or nil
	        if not Position then
	            return nil
	        end
	        local Travelled: number = (Position - Origin):Dot(Normal)
	        if Travelled >= Plane then
	            local Span: number = Travelled - Covered
	            return Previous:Lerp(Position, Span > 0.001 and (Plane - Covered) / Span or 0)
	        end
	        Previous, Covered = Position, Travelled
	    end
	
	    return nil
	end
	
	local function IsSafeLanding(Point: Vector3, Goal: BasePart, Mouth: Vector3): boolean
	    local Edge: number = GetEdge(0.3)
	    local Lateral: number = (Point - Mouth):Dot(Goal.CFrame.RightVector)
	
	    return math.abs(Lateral) < Goal.Size.X * 0.5 - Edge and math.abs(Point.Y - Mouth.Y) < Goal.Size.Y * 0.5 - Edge
	end
	
	local function GetReleaseDirection(Origin: Vector3, Call, Aim: Vector3, Normal: Vector3, Goal: BasePart, Mouth: Vector3, Charge: number?): Vector3?
	    local Fallback: Vector3?
	    for i: number = 0, 5 do
	        local Direction, Point = GetDirection(Origin, Call, Aim:Lerp(Mouth, i / 5), Normal, Charge)
	        if Direction and Point and IsSafeLanding(Point, Goal, Mouth) then
	            return Direction
	        end
	        Fallback = Direction or Fallback
	    end
	
	    return Fallback
	end
	
	local function GetSafeCurve(Origin: Vector3, Call, Direction: Vector3, Normal: Vector3, Goal: BasePart, Mouth: Vector3, Side: number, Charge: number?): number?
	    if not (AutoCurve and CurveAmount and AutoCurve.Enabled and Soccer.CurvedKicks.IsEnabled()) or typeof(CurveAmount.Value) ~= "number" then
	        return nil
	    end
	
	    local CurveDirection: number? = GetCurveDirection(Side, Normal, Goal)
	    if not CurveDirection then
	        return nil
	    end
	
	    local Maximum: number = math.floor(math.clamp(CurveAmount.Value, 1, 100) + 0.5)
	    Charge = Charge or GetCharge()
	    local Now: number = os.clock()
	    if CurveSolved.At and Now - CurveSolved.At < 0.1 and CurveSolved.Maximum == Maximum and CurveSolved.Goal == Goal and CurveSolved.Side == Side and math.abs(CurveSolved.Charge - Charge) < 0.04 and (CurveSolved.Origin - Origin).Magnitude < 0.5 and CurveSolved.Direction:Dot(Direction) > 0.9999 then
	        return CurveSolved.Value
	    end
	
	    local Plane: number = ((Mouth - Origin) * FlatMask):Dot(Normal)
	    local Boundary = Soccer.Renderer.GetMatchBoundaryWorld()
	    local Value: number? = nil
	    if Boundary and Plane > 0.01 then
	        local function IsSafe(Amount: number)
	            local Curve: number = CurveDirection * (Amount / 100)
	            local Velocity: Vector3? = GetLaunch(Origin, Call, Direction, Curve, Charge)
	            local Landing: Vector3? = Velocity and GetCurvedLanding(Origin, Velocity, Curve, Charge, Plane, Normal, Boundary) or nil
	            return Landing and IsSafeLanding(Landing, Goal, Mouth)
	        end
	
	        local Low, High = 0, Maximum
	        if IsSafe(Maximum) then
	            Low = Maximum
	        else
	            while High - Low > 1 do
	                local Amount: number = (Low + High) // 2
	                if IsSafe(Amount) then
	                    Low = Amount
	                else
	                    High = Amount
	                end
	            end
	        end
	        Value = Low > 0 and CurveDirection * (Low / 100) or nil
	    end
	
	    CurveSolved.At, CurveSolved.Maximum, CurveSolved.Goal, CurveSolved.Side = Now, Maximum, Goal, Side
	    CurveSolved.Charge, CurveSolved.Origin, CurveSolved.Direction, CurveSolved.Value = Charge, Origin, Direction, Value
	    return Value
	end
	
	local function GetBest(Goal: BasePart, Origin: Vector3, Call, Normal: Vector3, Mouth: Vector3)
	    local Keeper = GetKeeper(Goal)
	    local Feet: Vector3? = Keeper and Keeper.RootPart.Position - Vector3.new(0, Keeper.HipHeight, 0) or nil
	    local Plane: number = ((Mouth - Origin) * FlatMask):Dot(Normal)
	    local Top: number = GetTop(Goal)
	    local Wanted: number = math.min(Height.Value / 100, Top)
	    local Reachable: number = Mouth.Y + Goal.Size.Y * (Top - 0.5)
	    local FlightTime: number = Plane / math.max(Soccer.Shoot.Constants.Shot.MaximumSpeed * 0.85, 1)
	
	    local _, Point, Travel = GetDirection(Origin, Call, Mouth + Vector3.new(0, Goal.Size.Y * (Top - 0.5), 0), Normal)
	    if Point and Travel then
	        Reachable, FlightTime = Point.Y, Travel
	    end
	
	    local Cover: number = Keeper and Soccer.GoalkeeperDive.GetTravel(FlightTime) + Soccer.HitboxSettings.Receive.Size.X * 0.5 + Soccer.GoalkeeperDive.Constants.SaveContactPadding or 0
	    local Candidates = {}
	    for SideStep: number = -4, 4 do
	        for HeightStep: number = 0, 4 do
	            local Spot: number = SideStep / 4
	            local Raise: number = 0.12 + HeightStep * ((math.max(Wanted, 0.2) - 0.12) / 4)
	            local SpotPoint: Vector3 = Mouth + Goal.CFrame.RightVector * (Spot * (Goal.Size.X * 0.5 - SideInset)) + Vector3.new(0, Goal.Size.Y * (Raise - 0.5), 0)
	            if SpotPoint.Y <= Reachable + 0.3 then
	                local Score: number = -math.abs(Raise - Wanted) * 0.8 + Randomizer:NextNumber(0, 0.2)
	                if Feet then
	                    local Sideways: number = (Vector3.new(SpotPoint.X, Feet.Y, SpotPoint.Z) - Feet).Magnitude - Cover
	                    local Over: number = SpotPoint.Y - Feet.Y - Soccer.GoalkeeperDive.Constants.MaximumSaveHeight
	                    Score += math.clamp(math.max(Sideways, Over), -12, 0)
	                else
	                    Score += math.abs(Spot) * 0.3
	                end
	                table.insert(Candidates, {Side = Spot, Height = Raise, Point = SpotPoint, Score = Score})
	            end
	        end
	    end
	
	    table.sort(Candidates, function(A, B)
	        return A.Score > B.Score
	    end)
	
	    for i: number = 1, math.min(#Candidates, 4) do
	        local Candidate = Candidates[i]
	        local _, Landing = GetDirection(Origin, Call, Candidate.Point, Normal)
	        if Landing and IsSafeLanding(Landing, Goal, Mouth) then
	            return Candidate.Side, Candidate.Height
	        end
	    end
	
	    local First = Candidates[1]
	    return First and First.Side or 0, First and First.Height or Wanted
	end
	
	local function GetAim(Origin: Vector3, Call, Real: boolean?, Charge: number?)
	    local AimHeight = Height.Value
	    local MaxRange = Range.Value
	    local Angle = MaxAngle.Value
	    if typeof(Mode.Value) ~= "string" or typeof(AimHeight) ~= "number" or typeof(MaxRange) ~= "number" or typeof(Angle) ~= "number" then
	        return nil
	    end
	
	    local Goal = GetGoal(true)
	    if not Goal then
	        return nil
	    end
	    if (Goal.Position - Origin).Magnitude > MaxRange then
	        return nil
	    end
	
	    local Normal: Vector3 = (Goal.CFrame.LookVector * FlatMask).Unit
	    if ((Goal.Position - Origin) * FlatMask):Dot(Normal) < 0 then
	        Normal = -Normal
	    end
	
	    local Mouth: Vector3 = Goal.Position - Normal * (Goal.Size.Z * 0.5)
	    local Top: number = GetTop(Goal)
	    local Width: number = Goal.Size.X * 0.5 - SideInset
	    local Side: number = 0
	    AimHeight = math.clamp(AimHeight / 100, 1 - Top, Top)
	
	    if Mode.Value == "Best" then
	        if not Roll then
	            local Spot, Raise = GetBest(Goal, Origin, Call, Normal, Mouth)
	            Roll = {Side = Spot, Height = Raise}
	        end
	        Side, AimHeight = Roll.Side, Roll.Height
	    elseif Mode.Value == "Random" then
	        if not Roll then
	            local Keeper = GetKeeper(Goal)
	            local Away: number = Keeper and (Goal.CFrame.RightVector:Dot(Keeper.RootPart.Position - Goal.Position) < 0 and 1 or -1) or (Randomizer:NextInteger(0, 1) == 0 and -1 or 1)
	            Roll = {Side = Away * Randomizer:NextNumber(0.35, 1), Height = Randomizer:NextNumber(0.2, Top)}
	        end
	        Side = Roll.Side
	        AimHeight = Roll.Height
	    elseif Mode.Value == "Left" then
	        Side = -1
	    elseif Mode.Value == "Right" then
	        Side = 1
	    elseif Mode.Value ~= "Center" then
	        local Keeper = GetKeeper(Goal)
	        Side = Keeper and (Goal.CFrame.RightVector:Dot(Keeper.RootPart.Position - Goal.Position) < 0 and 1 or -1) or 1
	        if Mode.Value == "Top corners" then
	            AimHeight, Width = Top, Goal.Size.X * 0.5 - GetEdge()
	        end
	    end
	
	    local Forward: number = ((Mouth - Origin) * FlatMask):Dot(Normal)
	    local Lateral: number = (Origin - Mouth):Dot(Goal.CFrame.RightVector)
	    if Mode.Value ~= "Center" and math.abs(Lateral) > math.max(Forward * 1.5, 8) then
	        Side = Lateral > 0 and 1 or -1
	    end
	
	    if not Real and Fake.Enabled and (not ChargeStart or os.clock() - ChargeStart < GetSwitch()) then
	        Side = Side ~= 0 and -Side or 1
	    end
	
	    local Aim: Vector3 = Mouth + Goal.CFrame.RightVector * (Side * Width) + Vector3.new(0, Goal.Size.Y * (math.clamp(AimHeight, 1 - Top, Top) - 0.5), 0)
	    local Wanted: Vector3 = Aim - Origin
	    if Wanted.Magnitude < 0.01 then
	        return nil
	    end
	    local FlatWanted: Vector3 = Wanted * FlatMask
	    local FlatFacing: Vector3 = Camera.CFrame.LookVector * FlatMask
	    if not Real and FlatWanted.Magnitude > 0.01 and FlatFacing.Magnitude > 0.01 and math.deg(math.acos(math.clamp(FlatWanted.Unit:Dot(FlatFacing.Unit), -1, 1))) > Angle then
	        return nil
	    end
	
	    local Reach: number? = GetReach(Origin, Call, Aim, Normal, Charge or GetAimCharge())
	    if Reach and Aim.Y > Reach - 0.5 then
	        Aim = Vector3.new(Aim.X, math.max(Reach - 0.5, Mouth.Y + Goal.Size.Y * (0.5 - Top)), Aim.Z)
	    end
	
	    return Aim, Normal, Goal, Mouth, Side
	end
	
	local function Redirect(Call, Origin: Vector3, AimRay, Real: boolean, Charge: number?): Vector3?
	    local Aim, Normal, Goal, Mouth = GetAim(Origin, AimRay, Real, Charge)
	    if not Aim then
	        return nil
	    end
	
	    local Direction: Vector3?
	    if Real then
	        Direction = GetReleaseDirection(Origin, AimRay, Aim, Normal, Goal, Mouth, Charge) or (Aim - AimRay.Origin).Unit
	    else
	        Direction = GetDirection(Origin, AimRay, Aim, Normal, Charge)
	    end
	    if not Direction then
	        return nil
	    end
	
	    Call.AimDirection = GetAimRay(AimRay, Direction)
	    Call.KickDirection = Soccer.AimFacing.GetFlatDirection(Direction)
	
	    return Direction
	end
	
	ShotRedirect = vape.Categories.Combat:CreateModule({
	    Name = "ShotRedirect",
	    Function = function(Callback: boolean)
	        if Callback then
	            Marker = Instance.new("Part")
	            Marker.Anchored = true
	            Marker.CanCollide = false
	            Marker.CanQuery = false
	            Marker.CanTouch = false
	            Marker.Color = Color3.new(0.35, 1, 0.45)
	            Marker.Material = Enum.Material.Neon
	            Marker.Shape = Enum.PartType.Ball
	            Marker.Size = Vector3.new(2.5, 2.5, 2.5)
	            Marker.Transparency = 0.35
	            Marker.Parent = workspace
	
	            if not HookAim then
	                OldAim = Soccer.Aim.SetDirection
	                HookAim = function(Direction: Vector3)
	                    if BodyAim.Enabled and AimPoint and Entity.isAlive then
	                        local Wanted: Vector3 = (AimPoint - Entity.character.RootPart.Position) * FlatMask
	                        if Wanted.Magnitude > 0.01 then
	                            return OldAim(Wanted.Unit)
	                        end
	                    end
	                    return OldAim(Direction)
	                end
	
	                Soccer.Aim.SetDirection = HookAim
	            end
	
	            if not HookCommand then
	                OldCommand = Soccer.ActionCommands.Kick
	                HookCommand = function(...)
	                    local Call = OldCommand(...)
	                    if ShotRedirect.Enabled and Call and Call.PassType == Soccer.ActionCommands.PassTypes.Shot then
	                        local Release: boolean = Call.ChargeSeconds ~= nil
	                        local Origin: Vector3? = GetLaunchOrigin()
	                        local AimRay = Origin and Old and Old()
	                        local Direction
	                        if Release and LockedAim then
	                            Call.AimDirection, Call.KickDirection = LockedAim.AimDirection, LockedAim.KickDirection
	                            Direction = LockedAim.AimDirection.Direction
	                        elseif AimRay then
	                            Direction = Redirect(Call, Origin, AimRay, Release, Call.ChargeSeconds or GetAimCharge())
	                        end
	                        if AutoCurve.Enabled and AimRay then
	                            if not CurveLocked then
	                                local CurveCharge: number = Call.ChargeSeconds or Soccer.KickCore.Constants.MaximumChargeSeconds
	                                local RealAim, RealNormal, RealGoal, RealMouth, RealSide = GetAim(Origin, AimRay, true)
	                                local RealDirection = Release and Direction or (RealAim and GetDirection(Origin, AimRay, RealAim, RealNormal, CurveCharge) or nil)
	                                ShotCurve = RealDirection and GetSafeCurve(Origin, AimRay, RealDirection, RealNormal, RealGoal, RealMouth, RealSide, CurveCharge) or nil
	                                CurveLocked = true
	                            end
	                            Call.Curve = ShotCurve
	                            SetNativeCurve(ShotCurve)
	                        else
	                            ShotCurve = nil
	                            CurveLocked = false
	                            Call.Curve = nil
	                            SetNativeCurve(0)
	                        end
	                    end
	                    return Call
	                end
	                Soccer.ActionCommands.Kick = HookCommand
	            end
	
	            if not HookLock then
	                OldLock = Soccer.ActionRemoteProtocol.LockAim
	                HookLock = function(Command, ...)
	                    if ShotRedirect.Enabled and typeof(Command) == "table" and Command.PassType == Soccer.ActionCommands.PassTypes.Shot then
	                        local Origin: Vector3? = GetLaunchOrigin()
	                        local AimRay = Origin and Old()
	                        if AimRay and Redirect(Command, Origin, AimRay, true, Soccer.KickCore.Constants.MaximumChargeSeconds) then
	                            LockedAim = {AimDirection = Command.AimDirection, KickDirection = Command.KickDirection}
	                        end
	                    end
	                    return OldLock(Command, ...)
	                end
	                Soccer.ActionRemoteProtocol.LockAim = HookLock
	            end
	
	            if not HookEnded then
	                OldEnded = Soccer.ShootInput.HandleInputEnded
	                HookEnded = function(Input, ...)
	                    if ShotRedirect.Enabled and LockedAim and ChargeStart and Soccer.ShootInput.IsCharging() then
	                        local Remaining: number = Soccer.KickCore.Constants.MaximumChargeSeconds - (os.clock() - ChargeStart)
	                        if Remaining > 0 then
	                            local Arguments = table.pack(Input, ...)
	                            task.delay(Remaining + 0.03, function()
	                                OldEnded(table.unpack(Arguments, 1, Arguments.n))
	                            end)
	                            return true
	                        end
	                    end
	                    return OldEnded(Input, ...)
	                end
	                Soccer.ShootInput.HandleInputEnded = HookEnded
	            end
	
	            if not HookRay then
	                Old = Soccer.Reticle.GetCameraAimRayWithoutHit
	                HookRay = function(...)
	                    local Call = Old(...)
	                    if not ShotRedirect.Enabled or typeof(Call) ~= "table" or not Call.Origin then
	                        return Call
	                    end
	                    if Soccer.PassInput.IsCharging() then
	                        return Call
	                    end
	
	                    local Origin: Vector3? = GetOwnedPosition()
	                    local Aim, Normal
	                    if Origin then
	                        Aim, Normal = GetAim(Origin, Call)
	                    end
	                    local Direction = Aim and GetDirection(Origin, Call, Aim, Normal) or nil
	                    if not Direction then
	                        return Call
	                    end
	
	                    Call.Direction = Direction
	
	                    return Call
	                end
	
	                Soccer.Reticle.GetCameraAimRayWithoutHit = HookRay
	            end
	
	            ShotRedirect:Clean(RunService.RenderStepped:Connect(function(Delta: number)
	                local Charging: boolean = Soccer.ShootInput.IsCharging()
	                if Charging ~= WasCharging then
	                    WasCharging = Charging
	                    LockedAim = nil
	                    if Charging then
	                        ChargeStart = os.clock()
	                    else
	                        if ChargeStart then
	                            table.insert(Holds, 1, os.clock() - ChargeStart)
	                            if #Holds > 5 then
	                                table.remove(Holds)
	                            end
	                        end
	                        ChargeStart = nil
	                        Roll = nil
	                        ShotCurve = nil
	                        CurveLocked = false
	                        SetNativeCurve(nil)
	                    end
	                end
	
	                local Carried: Vector3? = Entity.isAlive and Soccer.Carry.GetVisualOwnedPosition(Entity.character.Character) or nil
	                local Origin: Vector3? = Carried or (Entity.isAlive and Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) and GetOwnedPosition() or nil)
	                local AimRay = Origin and Old()
	                local Aim, Normal
	                if AimRay then
	                    Aim, Normal = GetAim(Origin, AimRay)
	                end
	                AimPoint = Aim
	                Marker.Transparency = AimPoint and Display.Enabled and 0.35 or 1
	                if not AimPoint then
	                    return
	                end
	
	                Marker.Position = AimPoint
	                if not AutoAim.Enabled or not Soccer.ShootInput.IsCharging() then
	                    return
	                end
	
	                if Soccer.CameraBallSnap.IsActive() then
	                    Soccer.CameraBallSnap.Release()
	                end
	
	                local Wanted = GetDirection(Origin, AimRay, Aim, Normal)
	                if not Wanted or Wanted ~= Wanted then
	                    return
	                end
	
	                local Facing: Vector3 = Camera.CFrame.LookVector
	
	                local YawDifference: number = math.atan2(Facing.X, Facing.Z) - math.atan2(Wanted.X, Wanted.Z)
	                YawDifference = (YawDifference + math.pi) % (2 * math.pi) - math.pi
	                local Angle: Vector2 = Vector2.new(YawDifference, math.asin(Facing.Y) - math.asin(Wanted.Y)) // (MoveConstant * UserSettings():GetService("UserGameSettings").MouseSensitivity)
	                Angle *= math.min(AimSpeed.Value * Delta, 1)
	                mousemoverel(Angle.X, Angle.Y)
	            end))
	        else
	            if Soccer.Reticle.GetCameraAimRayWithoutHit == HookRay then
	                Soccer.Reticle.GetCameraAimRayWithoutHit = Old
	                HookRay = nil
	            end
	            if Soccer.Aim.SetDirection == HookAim then
	                Soccer.Aim.SetDirection = OldAim
	                HookAim = nil
	            end
	            if Soccer.ActionCommands.Kick == HookCommand then
	                Soccer.ActionCommands.Kick = OldCommand
	                HookCommand = nil
	            end
	            if Soccer.ActionRemoteProtocol.LockAim == HookLock then
	                Soccer.ActionRemoteProtocol.LockAim = OldLock
	                HookLock = nil
	            end
	            if Soccer.ShootInput.HandleInputEnded == HookEnded then
	                Soccer.ShootInput.HandleInputEnded = OldEnded
	                HookEnded = nil
	            end
	            AimPoint, Roll, WasCharging, ShotCurve, LockedAim = nil, nil, nil, nil, nil
	            CurveLocked = false
	            SetNativeCurve(nil)
	            table.clear(Solved)
	            table.clear(Reached)
	            table.clear(CurveSolved)
	            if Marker then
	                Marker:Destroy()
	                Marker = nil
	            end
	        end
	    end,
	    Tooltip = "Sends every shot you take into the enemy goal instead of where you aimed."
	})
	
	Mode = ShotRedirect:CreateDropdown({
	    Name = "Mode",
	    List = {"Best", "Random", "Top corners", "Away from keeper", "Left", "Right", "Center"},
	    Tooltip = "Which part of the goal to put the ball in. Best solves for the spot the keeper cannot reach in the balls flight time."
	})
	Height = ShotRedirect:CreateSlider({
	    Name = "Height",
	    Min = 0,
	    Max = 100,
	    Default = 55,
	    Suffix = "%",
	    Tooltip = "How high up the goal to aim, ignored on Top corners."
	})
	Fake = ShotRedirect:CreateToggle({
	    Name = "Fake",
	    Tooltip = "Shows and faces the opposite side while you charge, then sends the final release to the real spot."
	})
	PerfectFake = ShotRedirect:CreateToggle({
	    Name = "Perfect fake",
	    Default = true,
	    Tooltip = "Learns how long you actually hold shots and drops the decoy just before your shortest recent release, instead of using the slider."
	})
	Switch = ShotRedirect:CreateSlider({
	    Name = "Fake switch",
	    Min = 0.05,
	    Max = 0.4,
	    Default = 0.22,
	    Decimal = 100,
	    Suffix = "s",
	    Tooltip = "How long into the charge the decoy display drops, when Perfect fake is off. The final release still uses the real spot."
	})
	MaxAngle = ShotRedirect:CreateSlider({
	    Name = "Max angle",
	    Min = 1,
	    Max = 180,
	    Default = 180,
	    Tooltip = "Limits the preview angle; the final release still uses the safe goal target."
	})
	Range = ShotRedirect:CreateSlider({
	    Name = "Range",
	    Min = 10,
	    Max = 160,
	    Default = 160,
	    Tooltip = "Stops redirecting when the goal is further away than this."
	})
	BodyAim = ShotRedirect:CreateToggle({
	    Name = "Body aim",
	    Default = true,
	    Tooltip = "Turns your character onto the spot while you charge so the replay looks normal, without touching your camera."
	})
	AutoAim = ShotRedirect:CreateToggle({
	    Name = "Auto aim",
	    Default = true,
	    Tooltip = "Turns your camera onto the spot gradually instead of snapping, which looks more natural but can still be mid turn when you release. Only used when snap aim is off."
	})
	AimSpeed = ShotRedirect:CreateSlider({
	    Name = "Aim speed",
	    Min = 1,
	    Max = 30,
	    Default = 9,
	    Tooltip = "How quickly auto aim turns you onto the spot."
	})
	AutoCurve = ShotRedirect:CreateToggle({
	    Name = "Auto curve",
	    Default = true,
	    Tooltip = "Uses the strongest whole-percent curve up to your curve strength whose flight still enters the goal."
	})
	CurveAmount = ShotRedirect:CreateSlider({
	    Name = "Curve strength",
	    Min = 10,
	    Max = 100,
	    Default = 35,
	    Suffix = "%",
	    Tooltip = "Maximum curve to test. Auto curve lowers this only when the stronger flight would miss the goal."
	})
	Display = ShotRedirect:CreateToggle({
	    Name = "Display",
	    Default = true,
	    Tooltip = "Shows a marker on the spot your shot is going to."
	})
end)

Run(function()
	local TackleAssist
	local Targets
	local Range
	local Angle
	local BallCheck
	local Steer
	local BodyAim
	local StopDribble
	
	local FlatMask: Vector3 = Vector3.new(1, 0, 1)
	local Old, OldCommand
	local Hook, HookCommand
	local Target, SlideStart, AimDirection
	
	local function IsTackleable(Ent): boolean
	    if not (Ent.Targetable and Ent.Health > 0 and Ent.Character.Parent and Ent.RootPart.Parent) then
	        return false
	    end
	    if Ent.Character:GetAttribute("Ragdolled") then
	        return false
	    end
	
	    return not (StopDribble.Enabled and Soccer.Dodge.IsDribbling(Ent.Character))
	end
	
	local function GetContact(Distance: number): number
	    local Constants = Soccer.SlideTackle.Constants
	    local Ahead: number = -Soccer.HitboxSettings.SlideTackle.CFrameOffset.Z
	    for i: number = 0, 12 do
	        local Step: number = Constants.HitboxDelaySeconds + i * 0.025
	        if Soccer.SlideTackle.GetTravel(Step) + Ahead >= Distance then
	            return Step
	        end
	    end
	
	    return Constants.HitboxDelaySeconds + Constants.HitboxSeconds
	end
	
	local function GetAimPoint(Ent, Elapsed: number): Vector3
	    local Position: Vector3 = Ent.RootPart.Position
	    local Flat: Vector3 = (Position - Entity.character.RootPart.Position) * FlatMask
	    local Lead: number = math.max(GetContact(Flat.Magnitude) - Elapsed, 0)
	
	    return Position + (Ent.RootPart.AssemblyLinearVelocity * FlatMask * Lead)
	end
	
	local function GetTarget(LocalPosition: Vector3, Direction: Vector3)
	    local _, State = GetBall()
	    local Closest, Best = nil, math.cos(math.rad(Angle.Value))
	
	    for _, v: any in Entity.AllPosition({
	        Origin = LocalPosition,
	        Range = Range.Value,
	        Part = "RootPart",
	        Players = Targets.Players.Enabled,
	        NPCs = Targets.NPCs.Enabled
	    }) do
	        if not IsTackleable(v) then
	            continue
	        end
	        if BallCheck.Enabled then
	            local Carrying: boolean? = v.Player and Soccer.Renderer.GetBallOwnedBy(v.Player.UserId) ~= nil
	            if not Carrying and not (State and not v.Player and (v.RootPart.Position - State.Position).Magnitude <= 8) then
	                continue
	            end
	        end
	
	        local Flat: Vector3 = (v.RootPart.Position - LocalPosition) * FlatMask
	        local Facing: number = Flat.Magnitude > 0.01 and Flat.Unit:Dot(Direction) or -1
	        if Facing > Best then
	            Closest, Best = v, Facing
	        end
	    end
	
	    return Closest
	end
	
	TackleAssist = vape.Categories.Combat:CreateModule({
	    Name = "TackleAssist",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Hook then
	                Old = Soccer.SlideTackle.Run
	                Hook = function(Root: BasePart, Direction, Options, ...)
	                    if not (TackleAssist.Enabled and Entity.isAlive and Root == Entity.character.RootPart and typeof(Direction) == "Vector3") then
	                        return Old(Root, Direction, Options, ...)
	                    end
	
	                    Target, SlideStart, AimDirection = GetTarget(Root.Position, Direction), os.clock(), nil
	                    if not Target then
	                        return Old(Root, Direction, Options, ...)
	                    end
	
	                    AimDirection = Soccer.SlideTackle.GetAssistApproachDirection(Root, GetAimPoint(Target, 0), 0, Direction)
	                    local Facing: Vector3 = AimDirection * FlatMask
	                    if BodyAim.Enabled and Facing.Magnitude > 0.01 then
	                        Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Facing)
	                    end
	                    if Steer.Enabled and typeof(Options) == "table" and Options.GetDirection then
	                        local OldGet = Options.GetDirection
	                        Options.GetDirection = function(...)
	                            local Call = OldGet(...)
	                            if not (Target and Entity.isAlive and IsTackleable(Target)) then
	                                return Call
	                            end
	
	                            local Elapsed: number = os.clock() - SlideStart
	                            return Soccer.SlideTackle.GetAssistApproachDirection(Root, GetAimPoint(Target, Elapsed), Elapsed, Call)
	                        end
	                    end
	
	                    return Old(Root, AimDirection, Options, ...)
	                end
	                Soccer.SlideTackle.Run = Hook
	            end
	
	            if not HookCommand then
	                OldCommand = Soccer.ActionCommands.SlideTackle
	                HookCommand = function(...)
	                    local Call = OldCommand(...)
	                    if AimDirection and typeof(Call) == "table" then
	                        Call.AimDirection = AimDirection
	                    end
	
	                    return Call
	                end
	                Soccer.ActionCommands.SlideTackle = HookCommand
	            end
	
	            TackleAssist:Clean(RunService.PostSimulation:Connect(function()
	                if not (Target and SlideStart) then
	                    return
	                end
	
	                local Constants = Soccer.SlideTackle.Constants
	                local Elapsed: number = os.clock() - SlideStart
	                if Elapsed > Constants.HitboxDelaySeconds + Constants.HitboxSeconds or not Entity.isAlive or not IsTackleable(Target) then
	                    Target, SlideStart, AimDirection = nil, nil, nil
	                    return
	                end
	            end))
	        elseif Old then
	            if Soccer.SlideTackle.Run == Hook then
	                Soccer.SlideTackle.Run = Old
	                Hook = nil
	            end
	            if Soccer.ActionCommands.SlideTackle == HookCommand then
	                Soccer.ActionCommands.SlideTackle = OldCommand
	                HookCommand = nil
	            end
	            Target, SlideStart, AimDirection = nil, nil, nil
	        end
	    end,
	    Tooltip = "Aims the tackles you press yourself, steering the slide and turning your body onto the target so it lands."
	})
	
	Targets = TackleAssist:CreateTargets({
	    Players = true,
	    NPCs = true
	})
	Range = TackleAssist:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 28,
	    Default = 28,
	    Tooltip = "How far out opponents are worth aiming at. A slide only connects between 7.5 and 27.4 studs."
	})
	Angle = TackleAssist:CreateSlider({
	    Name = "Angle",
	    Min = 10,
	    Max = 180,
	    Default = 110,
	    Suffix = "degrees",
	    Tooltip = "How far off the way you are already sliding a target can be before it is left alone."
	})
	Steer = TackleAssist:CreateToggle({
	    Name = "Steer",
	    Default = true,
	    Tooltip = "Keeps correcting the slide while it is still steerable, which is the first 0.27s of it."
	})
	BodyAim = TackleAssist:CreateToggle({
	    Name = "Body aim",
	    Default = true,
	    Tooltip = "Faces your body toward the target when the slide begins without locking your camera for the whole tackle."
	})
	StopDribble = TackleAssist:CreateToggle({
	    Name = "Stop on dribble",
	    Default = true,
	    Tooltip = "Drops the target the moment they dribble, since the dodge makes them untouchable and chasing it only takes you out of position."
	})
	BallCheck = TackleAssist:CreateToggle({
	    Name = "Ball check",
	    Tooltip = "Only aims at the opponent who actually has the ball."
	})
end)

Run(function()
	local AutoDribble
	local Range
	local Lead
	local Predict
	local KickCheck
	local KickRange
	local KickCharge
	local FakeCheck
	local AnimationCheck
	local Delay
	
	local SlideAnimation: string = "rbxassetid://96680308558981"
	local KickAnimations: {[string]: boolean} = {["rbxassetid://102546600977181"] = true, ["rbxassetid://71638837796273"] = true}
	local Slides = setmetatable({}, {__mode = "k"})
	local NextDribble: number = 0
	
	local function GetSlideDirection(Ent, Elapsed: number): Vector3?
	    local Position: Vector3 = Ent.RootPart.Position * Vector3.new(1, 0, 1)
	    local Main: boolean = Elapsed >= Soccer.SlideTackle.Constants.StartupDashHandoffSeconds
	    local Sample = Slides[Ent.Character]
	    if not Sample or Sample.Main ~= Main then
	        Slides[Ent.Character] = {Position = Position, Main = Main, Direction = Sample and Sample.Direction or nil}
	        return Sample and Sample.Direction or nil
	    end
	
	    local Step: Vector3 = Position - Sample.Position
	    if Step.Magnitude >= 0.3 then
	        local Blend: Vector3 = Sample.Direction and (Sample.Direction + Step.Unit) or Step.Unit
	        Sample.Direction = Blend.Magnitude > 0.01 and Blend.Unit or Step.Unit
	        Sample.Position = Position
	    end
	
	    return Sample.Direction
	end
	
	local function GetImpact(Ent, Elapsed: number, LocalPosition: Vector3, LocalVelocity: Vector3): number?
	    local Forward: Vector3? = GetSlideDirection(Ent, Elapsed)
	    if not Forward then
	        return nil
	    end
	
	    local Opens: number = Soccer.SlideTackle.Constants.HitboxDelaySeconds
	    local Closes: number = Opens + Soccer.SlideTackle.Constants.HitboxSeconds
	    if FakeCheck.Enabled and Elapsed > Closes then
	        return nil
	    end
	
	    local Travelled: number = Soccer.SlideTackle.GetTravel(Elapsed)
	    local Size: Vector3 = Soccer.HitboxSettings.SlideTackle.Size * 0.5
	    local Center: Vector3 = Soccer.HitboxSettings.SlideTackle.CFrameOffset.Position
	    for i: number = 0, 20 do
	        local Step: number = i * 0.025
	        if not FakeCheck.Enabled or (Elapsed + Step >= Opens and Elapsed + Step <= Closes) then
	            local Ahead: Vector3 = Ent.RootPart.Position + Forward * (Soccer.SlideTackle.GetTravel(Elapsed + Step) - Travelled)
	            local Offset: Vector3 = CFrame.lookAt(Ahead, Ahead + Forward):PointToObjectSpace(LocalPosition + LocalVelocity * Step) - Center
	            if math.abs(Offset.X) <= Size.X and math.abs(Offset.Y) <= Size.Y and math.abs(Offset.Z) <= Size.Z then
	                return Step
	            end
	        end
	    end
	
	    return nil
	end
	
	local function GetTackler(LocalPosition: Vector3, LocalVelocity: Vector3)
	    local Now: number = workspace:GetServerTimeNow()
	    local Best, Soonest
	    for _, v: any in Entity.AllPosition({
	        Origin = LocalPosition,
	        Range = Range.Value,
	        Part = "RootPart",
	        Players = true,
	        NPCs = true
	    }) do
	        local Sliding: number? = Soccer.SlideTackle.GetSlidingUntil(v.Character)
	        if Sliding and Sliding > Now and not v.Character:GetAttribute("Ragdolled") then
	            local Animator: Animator? = AnimationCheck.Enabled and v.Humanoid:FindFirstChildOfClass("Animator") or nil
	            local Playing: boolean = Animator == nil
	            if Animator then
	                for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
	                    if Track.Animation and Track.Animation.AnimationId == SlideAnimation then
	                        Playing = true
	                        break
	                    end
	                end
	            end
	
	            if Playing then
	                local Elapsed: number = Now - (Sliding - Soccer.SlideTackle.Constants.TotalMotionSeconds)
	                local Impact: number? = Predict.Enabled and GetImpact(v, Elapsed, LocalPosition, LocalVelocity) or 0
	                if Impact and (not Soonest or Impact < Soonest) then
	                    Best, Soonest = v, Impact
	                end
	            end
	        end
	    end
	
	    return Best, Soonest
	end
	
	local function GetKicker(LocalPosition: Vector3)
	    local Size: Vector3 = Soccer.HitboxSettings.Kick.Size * 0.5
	    local Center: Vector3 = Soccer.HitboxSettings.Kick.CFrameOffset.Position
	    for _, v: any in Entity.AllPosition({
	        Origin = LocalPosition,
	        Range = KickRange.Value,
	        Part = "RootPart",
	        Players = true,
	        NPCs = true
	    }) do
	        local Animator: Animator? = v.Humanoid:FindFirstChildOfClass("Animator")
	        local Forward: Vector3? = Animator and Soccer.AimFacing.GetFlatDirection(v.RootPart.CFrame.LookVector) or nil
	        if Forward then
	            for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
	                local AnimationId = Track.Animation and Track.Animation.AnimationId
	                local Wound: number = KickAnimations[AnimationId] and Track.Length > 0.01 and Track.TimePosition / Track.Length or 0
	                if Wound >= KickCharge.Value / 100 then
	                    local Ahead: Vector3 = v.RootPart.Position + v.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.12
	                    local Offset: Vector3 = CFrame.lookAt(Ahead, Ahead + Forward):PointToObjectSpace(LocalPosition) - Center
	                    if math.abs(Offset.X) <= Size.X + 1 and math.abs(Offset.Y) <= Size.Y + 1 and math.abs(Offset.Z) <= Size.Z + 1 then
	                        return v
	                    end
	                end
	            end
	        end
	    end
	
	    return nil
	end
	
	AutoDribble = vape.Categories.Blatant:CreateModule({
	    Name = "AutoDribble",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait()
	                if not Entity.isAlive or os.clock() < NextDribble then
	                    continue
	                end
	                if not Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) or Soccer.Dodge.IsDribbling(LocalPlayer.Character) then
	                    continue
	                end
	
	                local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                local LocalVelocity: Vector3 = Entity.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	                local Tackler, Impact = GetTackler(LocalPosition, LocalVelocity)
	                if Tackler then
	                    if Predict.Enabled and Impact > Lead.Value + math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.4) then
	                        continue
	                    end
	                elseif not (KickCheck.Enabled and GetKicker(LocalPosition)) then
	                    continue
	                end
	
	                local Input = GetInput("Dribble")
	                if not Input then
	                    continue
	                end
	
	                NextDribble = os.clock() + Soccer.Dodge.Constants.CooldownSeconds + Delay:GetRandomValue()
	                Soccer.DodgeInput.HandleInputBegan(Input, false)
	            until not AutoDribble.Enabled
	        else
	            NextDribble = 0
	            table.clear(Slides)
	        end
	    end,
	    Tooltip = "Dribbles out of the way the moment an opponent slides at you."
	})
	
	Range = AutoDribble:CreateSlider({
	    Name = "Range",
	    Min = 5,
	    Max = 45,
	    Default = 32,
	    Tooltip = "How far away a sliding opponent is watched from."
	})
	Lead = AutoDribble:CreateSlider({
	    Name = "Lead",
	    Min = 0.05,
	    Max = 1,
	    Default = 0.6,
	    Decimal = 100,
	    Suffix = "s",
	    Tooltip = "How long before their slide reaches you that you dribble. The dodge protects you for a full second, so there is no reason to leave this short."
	})
	Predict = AutoDribble:CreateToggle({
	    Name = "Predict impact",
	    Default = true,
	    Tooltip = "Only dribbles when their slide is actually going to land on you."
	})
	KickCheck = AutoDribble:CreateToggle({
	    Name = "Kick check",
	    Default = true,
	    Tooltip = "Also dribbles away from tackle kicks, spotting the kick wind up animation on an opponent lined up on you."
	})
	KickRange = AutoDribble:CreateSlider({
	    Name = "Kick range",
	    Min = 3,
	    Max = 30,
	    Default = 12,
	    Tooltip = "How close an opponent winding up a kick has to be before you dribble out."
	})
	KickCharge = AutoDribble:CreateSlider({
	    Name = "Kick charge",
	    Min = 0,
	    Max = 100,
	    Default = 45,
	    Suffix = "%",
	    Tooltip = "How far into their kick wind up before it counts. A kick only knocks you fully at high charge, so this stops weak taps burning your dribble."
	})
	FakeCheck = AutoDribble:CreateToggle({
	    Name = "Fake check",
	    Default = true,
	    Tooltip = "Only spends your dribble when their slide can still connect, so a baited tackle cannot waste it."
	})
	AnimationCheck = AutoDribble:CreateToggle({
	    Name = "Animation check",
	    Default = true,
	    Tooltip = "Waits until the tackle animation is really playing on them."
	})
	Delay = AutoDribble:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0,
	    DefaultMax = 0.05,
	    Decimal = 100
	})
end)

Run(function()
	local AutoTackle
	local Targets
	local Range
	local Angle
	local Delay
	local BallCheck
	local DodgeCheck
	local SafeRange
	local Face
	
	local NextTackle: number = 0
	local Dribbles = setmetatable({}, {__mode = "k"})
	
	local function GetAim(): Vector3
	    local Moving: Vector3 = Entity.character.Humanoid.MoveDirection * Vector3.new(1, 0, 1)
	    if Moving.Magnitude > 0.05 then
	        return Moving.Unit
	    end
	
	    local Look: Vector3 = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	    return Look.Magnitude > 0.01 and Look.Unit or Soccer.SlideTackle.GetFlatForward(Entity.character.RootPart)
	end
	
	local function GetTarget(LocalPosition: Vector3)
	    local _, State = GetBall()
	    local Carrier = GetCarrier()
	    local Aim, Limit = GetAim(), math.cos(math.rad(Angle.Value))
	    local Closest, Distance = nil, math.huge
	
	    for _, v: any in Entity.AllPosition({
	        Origin = LocalPosition,
	        Range = Range.Value,
	        Part = "RootPart",
	        Players = Targets.Players.Enabled,
	        NPCs = Targets.NPCs.Enabled
	    }) do
	        if Soccer.Dodge.IsDribbling(v.Character) then
	            Dribbles[v.Character] = os.clock()
	        end
	
	        local Flat: Vector3 = (v.RootPart.Position - LocalPosition) * Vector3.new(1, 0, 1)
	        if Flat.Magnitude > 0.01 and Flat.Unit:Dot(Aim) < Limit then
	            continue
	        end
	
	        if not BallCheck.Enabled then
	            return v, State
	        end
	
	        if v == Carrier or v.Player and Soccer.Renderer.GetBallOwnedBy(v.Player.UserId) then
	            return v, State
	        end
	
	        if State and not v.Player then
	            local Magnitude: number = (v.RootPart.Position - State.Position).Magnitude
	            if Magnitude < Distance and Magnitude <= 8 then
	                Closest, Distance = v, Magnitude
	            end
	        end
	    end
	
	    return Closest, State
	end
	
	local function GetContact(Target, LocalPosition: Vector3)
	    local Velocity: Vector3 = Target.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	    local Ahead: number = -Soccer.HitboxSettings.SlideTackle.CFrameOffset.Z
	    local Slack: number = Soccer.HitboxSettings.SlideTackle.Size.X * 0.5
	    for i: number = 0, 12 do
	        local Step: number = Soccer.SlideTackle.Constants.HitboxDelaySeconds + i * 0.025
	        local Predicted: Vector3 = Target.RootPart.Position + Velocity * Step
	        local Flat: Vector3 = (Predicted - LocalPosition) * Vector3.new(1, 0, 1)
	        if math.abs(Flat.Magnitude - (Soccer.SlideTackle.GetTravel(Step) + Ahead)) <= Slack then
	            return Step, Predicted
	        end
	    end
	
	    return nil
	end
	
	AutoTackle = vape.Categories.Blatant:CreateModule({
	    Name = "AutoTackle",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait()
	                if not Entity.isAlive or os.clock() < NextTackle then
	                    continue
	                end
	                if Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) then
	                    continue
	                end
	
	                local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                local Target, State = GetTarget(LocalPosition)
	                if not Target then
	                    continue
	                end
	                if BallCheck.Enabled and State and (State.Position - LocalPosition).Magnitude < (Target.RootPart.Position - State.Position).Magnitude then
	                    continue
	                end
	                if Soccer.Dodge.IsDribbling(Target.Character) then
	                    continue
	                end
	
	                local LastDribble: number? = Dribbles[Target.Character]
	                if DodgeCheck.Enabled and (not LastDribble or os.clock() - LastDribble > Soccer.Dodge.Constants.CooldownSeconds) and (Target.RootPart.Position - LocalPosition).Magnitude > SafeRange.Value then
	                    continue
	                end
	
	                local _, Predicted = GetContact(Target, LocalPosition)
	                if not Predicted then
	                    continue
	                end
	
	                local Direction: Vector3 = (Predicted - LocalPosition) * Vector3.new(1, 0, 1)
	                local Input = Direction.Magnitude > 0.01 and GetInput("Tackle") or nil
	                if not Input then
	                    continue
	                end
	
	                Direction = Direction.Unit
	                if Face.Enabled then
	                    Entity.character.RootPart.CFrame = CFrame.lookAt(LocalPosition, LocalPosition + Direction)
	                end
	
	                MoveCharacter(Direction)
	                NextTackle = os.clock() + Soccer.SlideTackle.Constants.CooldownSeconds + Delay:GetRandomValue()
	                Soccer.SlideTackleInput.HandleInputBegan(Input, false)
	            until not AutoTackle.Enabled
	        else
	            NextTackle = 0
	            table.clear(Dribbles)
	        end
	    end,
	    Tooltip = "Slide tackles opponents, waiting for the moment their dribble cannot save them."
	})
	
	Targets = AutoTackle:CreateTargets({
	    Players = true,
	    NPCs = true
	})
	Range = AutoTackle:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 28,
	    Default = 28,
	    Tooltip = "How far out opponents are considered. The slide only connects between 7.5 and 27.4 studs, so it holds fire outside that."
	})
	Angle = AutoTackle:CreateSlider({
	    Name = "Angle",
	    Min = 10,
	    Max = 180,
	    Default = 180,
	    Suffix = "degrees",
	    Tooltip = "How far off the way you are running an opponent can be before they are left alone. Measured from your camera while you stand still."
	})
	Delay = AutoTackle:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 2,
	    DefaultMin = 0,
	    DefaultMax = 0.15,
	    Decimal = 100
	})
	BallCheck = AutoTackle:CreateToggle({
	    Name = "Ball check",
	    Default = true,
	    Tooltip = "Only tackles the opponent who actually has the ball."
	})
	DodgeCheck = AutoTackle:CreateToggle({
	    Name = "Dodge check",
	    Default = true,
	    Tooltip = "Holds the tackle while their dribble is off cooldown, so they cannot dodge it."
	})
	SafeRange = AutoTackle:CreateSlider({
	    Name = "Safe range",
	    Min = 1,
	    Max = 28,
	    Default = 11,
	    Tooltip = "How close they must be before you tackle anyway with their dribble ready."
	})
	Face = AutoTackle:CreateToggle({
	    Name = "Face target",
	    Default = true,
	    Tooltip = "Also turns your body into the slide, which is what aims it when you are standing still."
	})
end)

Run(function()
	local BallHitbox
	local Range
	local Vertical
	local Airborne
	
	local FlatMask: Vector3 = Vector3.new(1, 0, 1)
	local PullCooldown: number = 0.4
	local NextPull: number = 0
	
	BallHitbox = vape.Categories.Blatant:CreateModule({
	    Name = "BallHitbox",
	    Function = function(Callback: boolean)
	        if Callback then
	            NextPull = 0
	            BallHitbox:Clean(RunService.PostSimulation:Connect(function()
	                if not Entity.isAlive or os.clock() < NextPull then
	                    return
	                end
	
	                local _, State = GetBall()
	                if not State or State.Mode == "Resting" or Soccer.Renderer.GetMainMatchOwnerUserId() then
	                    return
	                end
	                if not Airborne.Enabled and State.Mode == "Airborne" then
	                    return
	                end
	
	                local Character: Model = Entity.character.Character
	                if Soccer.Dodge.IsDribbling(Character) then
	                    return
	                end
	                if (Soccer.SlideTackle.GetSlidingUntil(Character) or 0) > workspace:GetServerTimeNow() then
	                    return
	                end
	                if Soccer.Ownership.IsWithinReceiveHitbox(Character, State.Position) then
	                    return
	                end
	
	                local Root: BasePart = Entity.character.RootPart
	                local Wanted: Vector3 = State.Position - Soccer.HitboxSettings.Receive.CFrameOffset.Position - Root.Position
	                local Move: Vector3 = Vertical.Enabled and Wanted or (Wanted * FlatMask)
	                if Move.Magnitude < 0.05 or Move.Magnitude > Range.Value then
	                    return
	                end
	
	                NextPull = os.clock() + PullCooldown
	                Root.CFrame += Move
	            end))
	        end
	    end,
	    Tooltip = "Pulls you onto a loose ball that lands just out of reach. The game decides who receives the ball on the server, so the only way to widen it is to be where the ball is."
	})
	
	Range = BallHitbox:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 30,
	    Default = 10,
	    Tooltip = "How far you will be pulled to reach the ball. Anything under 2.75 studs is already inside the real hitbox, and the further you set this the more it looks like a teleport."
	})
	Airborne = BallHitbox:CreateToggle({
	    Name = "Airborne",
	    Default = true,
	    Tooltip = "Also grabs balls that are still in the air rather than only ones rolling on the ground."
	})
	Vertical = BallHitbox:CreateToggle({
	    Name = "Vertical",
	    Tooltip = "Lets it pull you up or down as well, so headers and drops count. Off by default because it looks like flying."
	})
end)

Run(function()
	local BallChanger
	local Skin
	
	local Old: (...any) -> ...any
	local Hook: ((...any) -> ...any)?
	local Real: {[any]: string} = {}
	
	local function GetNames(Category): {string}
	    local Names: {string} = {}
	    local Success, Folder = pcall(Soccer.Catalog.GetFolder, Category)
	    if Success and Folder then
	        for _, v: Instance in Folder:GetChildren() do
	            if v.Name ~= Soccer.Catalog.DefaultName then
	                table.insert(Names, v.Name)
	            end
	        end
	    end
	
	    table.sort(Names)
	    table.insert(Names, 1, Soccer.Catalog.DefaultName)
	    return Names
	end
	
	BallChanger = vape.Categories.Render:CreateModule({
	    Name = "BallChanger",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Hook then
	                Old = Soccer.Renderer.SetSkin
	                Hook = function(BallId, Name: string, ...)
	                    Real[BallId] = Name
	                    if BallChanger.Enabled and Skin.Value ~= Soccer.Catalog.DefaultName then
	                        return Old(BallId, Skin.Value, ...)
	                    end
	
	                    return Old(BallId, Name, ...)
	                end
	                Soccer.Renderer.SetSkin = Hook
	            end
	
	            BallChanger:Clean(RunService.Heartbeat:Connect(function()
	                local BallId = Soccer.Renderer.GetMatchBallId()
	                if not BallId or Soccer.Renderer.GetSkinName(BallId) == Skin.Value then
	                    return
	                end
	
	                Soccer.Renderer.SetSkin(BallId, Skin.Value)
	            end))
	        elseif Old then
	            if Soccer.Renderer.SetSkin == Hook then
	                Soccer.Renderer.SetSkin = Old
	                Hook = nil
	            end
	            for i, v: string in Real do
	                pcall(Old, i, v)
	            end
	            table.clear(Real)
	        end
	    end,
	    Tooltip = "Puts any ball skin on the match ball. It is your own view of it, so nobody else sees the change."
	})
	
	Skin = BallChanger:CreateDropdown({
	    Name = "Skin",
	    List = GetNames(Soccer.Catalog.Categories.Balls),
	    Tooltip = "Which skin to wear. Every one the game ships is here whether you own it or not."
	})
end)

Run(function()
	local BallPredict
	local Box
	local BoundingBox
	local Nametag
	local Background
	local Arc
	local LandingSpot
	local KeeperThrow
	local Horizon
	local Points
	local Color
	
	local Folder: Folder?
	local Parts: {Part} = {}
	local Landing: Part?
	local Keeper: Part?
	local Drawings = {}
	
	local function GetThrow(): Vector3?
	    local Team: string? = Soccer.ActorTeams.GetActorTeamName(LocalPlayer)
	    if not Team then
	        return nil
	    end
	
	    local Thrower
	    for _, v: any in Entity.List do
	        if v.Targetable and Soccer.Carry.IsGoalkeeperCarry(v.Character) then
	            Thrower = v
	            break
	        end
	    end
	
	    if not Thrower then
	        return nil
	    end
	
	    local Goal = GetGoal(false)
	    local Best, BestScore
	    for _, v: any in Entity.List do
	        if v.Targetable and v ~= Thrower then
	            local Score: number = Goal and -(Goal.Position - v.RootPart.Position).Magnitude or -(Thrower.RootPart.Position - v.RootPart.Position).Magnitude
	            for _, Blocker: any in Entity.List do
	                if not Blocker.Targetable then
	                    local Offset: Vector3 = Blocker.RootPart.Position - Thrower.RootPart.Position
	                    local Lane: Vector3 = v.RootPart.Position - Thrower.RootPart.Position
	                    if Lane.Magnitude > 0.01 and (Offset - Lane.Unit * math.clamp(Offset:Dot(Lane.Unit), 0, Lane.Magnitude)).Magnitude < 8 then
	                        Score -= 60
	                    end
	                end
	            end
	            if not BestScore or Score > BestScore then
	                Best, BestScore = v, Score
	            end
	        end
	    end
	
	    return Best and Best.RootPart.Position or nil
	end
	
	BallPredict = vape.Categories.Render:CreateModule({
	    Name = "BallPredict",
	    Function = function(Callback: boolean)
	        if Callback then
	            Folder = Instance.new("Folder")
	            Folder.Parent = workspace
	
	            for i: number = 1, 40 do
	                local Part: Part = Instance.new("Part")
	                Part.Anchored = true
	                Part.CanCollide = false
	                Part.CanQuery = false
	                Part.CanTouch = false
	                Part.Material = Enum.Material.Neon
	                Part.Shape = Enum.PartType.Ball
	                Part.Size = Vector3.new(0.6, 0.6, 0.6)
	                Part.Transparency = 1
	                Part.Parent = Folder
	                Parts[i] = Part
	            end
	
	            Landing = Parts[1]:Clone()
	            Landing.Size = Vector3.new(3, 0.3, 3)
	            Landing.Shape = Enum.PartType.Cylinder
	            Landing.Parent = Folder
	            Keeper = Parts[1]:Clone()
	            Keeper.Size = Vector3.new(3.5, 3.5, 3.5)
	            Keeper.Parent = Folder
	
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	            Drawings.Main = Drawing.new("Square")
	            Drawings.Main.Transparency = BoundingBox.Enabled and 1 or 0
	            Drawings.Main.ZIndex = 2
	            Drawings.Main.Filled = false
	            Drawings.Main.Thickness = 1
	            Drawings.Border = Drawing.new("Square")
	            Drawings.Border.Transparency = 0.35
	            Drawings.Border.ZIndex = 1
	            Drawings.Border.Thickness = 1
	            Drawings.Border.Filled = false
	            Drawings.Border.Color = Color3.new()
	            Drawings.Border2 = Drawing.new("Square")
	            Drawings.Border2.Transparency = 0.35
	            Drawings.Border2.ZIndex = 1
	            Drawings.Border2.Thickness = 1
	            Drawings.Border2.Filled = false
	            Drawings.Border2.Color = Color3.new()
	            Drawings.TextBKG = Drawing.new("Square")
	            Drawings.TextBKG.Transparency = 0.35
	            Drawings.TextBKG.ZIndex = 0
	            Drawings.TextBKG.Thickness = 1
	            Drawings.TextBKG.Filled = true
	            Drawings.TextBKG.Color = Color3.new()
	            Drawings.Drop = Drawing.new("Text")
	            Drawings.Drop.Color = Color3.new()
	            Drawings.Drop.ZIndex = 1
	            Drawings.Drop.Center = true
	            Drawings.Drop.Size = 20
	            Drawings.Text = Drawing.new("Text")
	            Drawings.Text.ZIndex = 2
	            Drawings.Text.Center = true
	            Drawings.Text.Size = 20
	
	            BallPredict:Clean(RunService.RenderStepped:Connect(function()
	                local BallId, State = GetBall()
	                local Shade: Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                local Spot: Vector3? = KeeperThrow.Enabled and GetThrow() or nil
	                Keeper.Transparency = Spot and 0.4 or 1
	                Keeper.Color = Shade
	                if Spot then
	                    Keeper.Position = Spot + Vector3.new(0, 4, 0)
	                end
	
	                local Ball = BallId and workspace.Misc.Visuals:FindFirstChild(`ClientBall_{BallId}`) or nil
	                if not State or not Ball then
	                    Landing.Transparency = 1
	                    for _, v: Part in Parts do
	                        v.Transparency = 1
	                    end
	                    for _, v: any in Drawings do
	                        v.Visible = false
	                    end
	                    return
	                end
	
	                local Rolling: boolean = State.Mode == "Rolling" or State.Mode == "Resting"
	                local Ground, Drop
	                for i: number, v: Part in Parts do
	                    local Step: number = i * (Horizon.Value / #Parts)
	                    local Position: Vector3 = Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, Step)
	                    v.Color = Shade
	                    v.Position = Position
	                    v.Transparency = Arc.Enabled and i <= Points.Value and 0.35 or 1
	                    if not Ground and (Rolling and i == #Parts or (not Rolling and Position.Y <= State.Radius + 1.1)) then
	                        Ground, Drop = Position, Step
	                    end
	                end
	
	                Landing.Color = Shade
	                Landing.Transparency = Ground and LandingSpot.Enabled and 0.3 or 1
	                if Ground then
	                    Landing.CFrame = CFrame.new(Ground.X, State.Radius + 0.2, Ground.Z) * CFrame.Angles(0, 0, math.rad(90))
	                end
	
	                local BallPosition, BallVisible = Camera:WorldToViewportPoint(Ball.Position)
	                for _, v: any in Drawings do
	                    v.Visible = BallVisible
	                end
	                if not BallVisible then
	                    return
	                end
	
	                local Radius: number = Ball.Size.X * 0.5 + 0.3
	                local Facing: CFrame = CFrame.lookAlong(Ball.Position, Camera.CFrame.LookVector)
	                local TopPos: Vector3 = Camera:WorldToViewportPoint((Facing * CFrame.new(Radius, Radius, 0)).p)
	                local BottomPos: Vector3 = Camera:WorldToViewportPoint((Facing * CFrame.new(-Radius, -Radius, 0)).p)
	                local SizeX, SizeY = TopPos.X - BottomPos.X, TopPos.Y - BottomPos.Y
	                local PosX, PosY = BallPosition.X - SizeX / 2, BallPosition.Y - SizeY / 2
	                Drawings.Main.Visible = Box.Enabled
	                Drawings.Main.Color = Shade
	                Drawings.Main.Transparency = BoundingBox.Enabled and 1 or 0
	                Drawings.Main.Position = Vector2.new(PosX, PosY) // 1
	                Drawings.Main.Size = Vector2.new(SizeX, SizeY) // 1
	                Drawings.Border.Visible = Box.Enabled and BoundingBox.Enabled
	                Drawings.Border.Position = Vector2.new(PosX - 1, PosY + 1) // 1
	                Drawings.Border.Size = Vector2.new(SizeX + 2, SizeY - 2) // 1
	                Drawings.Border2.Visible = Drawings.Border.Visible
	                Drawings.Border2.Position = Vector2.new(PosX + 1, PosY - 1) // 1
	                Drawings.Border2.Size = Vector2.new(SizeX - 2, SizeY + 2) // 1
	
	                local Text: string = "Ball"
	                if Ground then
	                    Text = `{Text} [{math.floor((Ground - State.Position).Magnitude)}m]`
	                    if not Rolling then
	                        Text = `{Text} {string.format("%.1f", Drop)}s`
	                    end
	                end
	
	                Drawings.Text.Visible = Nametag.Enabled
	                Drawings.Text.Color = Shade
	                Drawings.Text.Text = Text
	                Drawings.Text.Position = Vector2.new(BallPosition.X, PosY - 22) // 1
	                Drawings.Drop.Visible = Nametag.Enabled
	                Drawings.Drop.Text = Text
	                Drawings.Drop.Position = Drawings.Text.Position + Vector2.new(1, 1)
	                Drawings.TextBKG.Visible = Nametag.Enabled and Background.Enabled
	                Drawings.TextBKG.Size = Drawings.Text.TextBounds + Vector2.new(8, 4)
	                Drawings.TextBKG.Position = Drawings.Text.Position - Vector2.new(4 + (Drawings.Text.TextBounds.X / 2), 0)
	            end))
	        else
	            if Folder then
	                Folder:Destroy()
	                Folder = nil
	            end
	            for _, v: any in Drawings do
	                v:Remove()
	            end
	            table.clear(Drawings)
	            table.clear(Parts)
	            Landing, Keeper = nil, nil
	        end
	    end,
	    Tooltip = "Boxes the ball and draws where it is going, where it lands and who the enemy keeper is about to throw to."
	})
	
	Box = BallPredict:CreateToggle({
	    Name = "Box",
	    Default = true,
	    Tooltip = "Draws a 2D box around the ball."
	})
	BoundingBox = BallPredict:CreateToggle({
	    Name = "Bounding Box",
	    Default = true,
	    Tooltip = "Outlines the box in black so it reads against the pitch."
	})
	Nametag = BallPredict:CreateToggle({
	    Name = "Nametag",
	    Default = true,
	    Tooltip = "Labels the ball with how far it travels and how long until it lands."
	})
	Background = BallPredict:CreateToggle({
	    Name = "Show Background",
	    Default = true,
	    Tooltip = "Fills a dark box behind the label."
	})
	Arc = BallPredict:CreateToggle({
	    Name = "Arc",
	    Default = true,
	    Tooltip = "Draws the balls flight path."
	})
	LandingSpot = BallPredict:CreateToggle({
	    Name = "Landing",
	    Default = true,
	    Tooltip = "Marks the spot the ball is going to land on."
	})
	KeeperThrow = BallPredict:CreateToggle({
	    Name = "Keeper throw",
	    Default = true,
	    Tooltip = "Marks the player the enemy keeper is most likely to throw to."
	})
	Horizon = BallPredict:CreateSlider({
	    Name = "Horizon",
	    Min = 0.5,
	    Max = 6,
	    Default = 3,
	    Decimal = 10,
	    Suffix = "s",
	    Tooltip = "How far ahead the flight is read."
	})
	Points = BallPredict:CreateSlider({
	    Name = "Points",
	    Min = 4,
	    Max = 40,
	    Default = 24,
	    Tooltip = "How many dots the path is drawn with."
	})
	Color = BallPredict:CreateColorSlider({
	    Name = "Color",
	    DefaultHue = 0.15
	})
end)

Run(function()
	local GoalChanger
	local Effect
	local OwnTeam
	
	local Old: (...any) -> ...any
	local Hook: ((...any) -> ...any)?
	
	local function GetNames(Category): {string}
	    local Names: {string} = {}
	    local Success, Folder = pcall(Soccer.Catalog.GetFolder, Category)
	    if Success and Folder then
	        for _, v: Instance in Folder:GetChildren() do
	            if v.Name ~= Soccer.Catalog.DefaultName then
	                table.insert(Names, v.Name)
	            end
	        end
	    end
	
	    table.sort(Names)
	    table.insert(Names, 1, Soccer.Catalog.DefaultName)
	    return Names
	end
	
	local function IsOurs(GoalPart: Instance?): boolean
	    if not OwnTeam.Enabled then
	        return true
	    end
	
	    local Goal = GetGoal(true)
	    return Goal ~= nil and GoalPart ~= nil and (GoalPart == Goal or GoalPart:IsDescendantOf(Goal))
	end
	
	GoalChanger = vape.Categories.Render:CreateModule({
	    Name = "GoalChanger",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Hook then
	                Old = Soccer.GoalEffect.Play
	                Hook = function(Name: string, Position: Vector3, GoalPart: Instance?, ...)
	                    if GoalChanger.Enabled and Effect.Value ~= Soccer.Catalog.DefaultName and IsOurs(GoalPart) then
	                        pcall(Soccer.GoalEffect.Preload, {Effect.Value})
	                        return Old(Effect.Value, Position, GoalPart, ...)
	                    end
	
	                    return Old(Name, Position, GoalPart, ...)
	                end
	                Soccer.GoalEffect.Play = Hook
	            end
	        elseif Soccer.GoalEffect.Play == Hook then
	            Soccer.GoalEffect.Play = Old
	            Hook = nil
	        end
	    end,
	    Tooltip = "Plays any goal effect when the net goes. It is your own view of it, so nobody else sees the change."
	})
	
	Effect = GoalChanger:CreateDropdown({
	    Name = "Effect",
	    List = GetNames(Soccer.Catalog.Categories.GoalEffects),
	    Tooltip = "Which effect to play. Every one the game ships is here whether you own it or not."
	})
	OwnTeam = GoalChanger:CreateToggle({
	    Name = "Own team",
	    Default = true,
	    Tooltip = "Only replaces the effect for goals your team scores, so the other side keeps theirs."
	})
end)

Run(function()
	local GoalESP
	local Box
	local Nametag
	local OwnGoal
	local Size
	local Opacity
	local Color
	
	local Drawings = {}
	
	GoalESP = vape.Categories.Render:CreateModule({
	    Name = "GoalESP",
	    Function = function(Callback: boolean)
	        if Callback then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            for i: number = 1, 2 do
	                local DrawingSet = {}
	                DrawingSet.Main = Drawing.new("Square")
	                DrawingSet.Main.Thickness = 1
	                DrawingSet.Main.Filled = false
	                DrawingSet.Main.ZIndex = 2
	                DrawingSet.Drop = Drawing.new("Text")
	                DrawingSet.Drop.Color = Color3.new()
	                DrawingSet.Drop.ZIndex = 1
	                DrawingSet.Drop.Center = true
	                DrawingSet.Drop.Size = 16
	                DrawingSet.Text = Drawing.new("Text")
	                DrawingSet.Text.ZIndex = 2
	                DrawingSet.Text.Center = true
	                DrawingSet.Text.Size = 16
	                Drawings[i] = DrawingSet
	            end
	
	            GoalESP:Clean(RunService.RenderStepped:Connect(function()
	                local Shade: Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                for i: number, v: {Goal: BasePart?, Label: string} in {{Goal = GetGoal(true), Label = "Goal"}, {Goal = OwnGoal.Enabled and GetGoal(false) or nil, Label = "Your Goal"}} do
	                    local DrawingSet = Drawings[i]
	                    local Center, Visible
	                    if v.Goal then
	                        Center, Visible = Camera:WorldToViewportPoint(v.Goal.Position)
	                    end
	                    if not Visible then
	                        for _, Object: any in DrawingSet do
	                            Object.Visible = false
	                        end
	                        continue
	                    end
	
	                    local Facing: CFrame = CFrame.lookAlong(v.Goal.Position, Camera.CFrame.LookVector)
	                    local TopPos: Vector3 = Camera:WorldToViewportPoint((Facing * CFrame.new(Size.Value, Size.Value, 0)).p)
	                    local BottomPos: Vector3 = Camera:WorldToViewportPoint((Facing * CFrame.new(-Size.Value, -Size.Value, 0)).p)
	                    local SizeX, SizeY = TopPos.X - BottomPos.X, TopPos.Y - BottomPos.Y
	                    DrawingSet.Main.Visible = Box.Enabled
	                    DrawingSet.Main.Color = Shade
	                    DrawingSet.Main.Transparency = Opacity.Value / 100
	                    DrawingSet.Main.Position = Vector2.new(Center.X - SizeX / 2, Center.Y - SizeY / 2) // 1
	                    DrawingSet.Main.Size = Vector2.new(SizeX, SizeY) // 1
	
	                    local Text: string = v.Label
	                    if Entity.isAlive then
	                        Text = `{Text} [{math.floor((v.Goal.Position - Entity.character.RootPart.Position).Magnitude)}m]`
	                    end
	
	                    DrawingSet.Text.Visible = Nametag.Enabled
	                    DrawingSet.Text.Color = Shade
	                    DrawingSet.Text.Transparency = Opacity.Value / 100
	                    DrawingSet.Text.Text = Text
	                    DrawingSet.Text.Position = Vector2.new(Center.X, Center.Y - SizeY / 2 - 18) // 1
	                    DrawingSet.Drop.Visible = Nametag.Enabled
	                    DrawingSet.Drop.Transparency = Opacity.Value / 100
	                    DrawingSet.Drop.Text = Text
	                    DrawingSet.Drop.Position = DrawingSet.Text.Position + Vector2.new(1, 1)
	                end
	            end))
	        else
	            for _, v: any in Drawings do
	                for _, Object: any in v do
	                    Object:Remove()
	                end
	            end
	            table.clear(Drawings)
	        end
	    end,
	    Tooltip = "Marks the middle of the goal so you always know where you are shooting."
	})
	
	Box = GoalESP:CreateToggle({
	    Name = "Box",
	    Default = true,
	    Tooltip = "Draws a small box on the middle of the goal."
	})
	Nametag = GoalESP:CreateToggle({
	    Name = "Nametag",
	    Default = true,
	    Tooltip = "Labels the middle of the goal with its distance."
	})
	OwnGoal = GoalESP:CreateToggle({
	    Name = "Own goal",
	    Tooltip = "Marks the goal you are defending as well as the one you are attacking."
	})
	Size = GoalESP:CreateSlider({
	    Name = "Size",
	    Min = 1,
	    Max = 18,
	    Default = 3,
	    Tooltip = "How big the marker on the goal is, in studs."
	})
	Opacity = GoalESP:CreateSlider({
	    Name = "Opacity",
	    Min = 5,
	    Max = 100,
	    Default = 45,
	    Suffix = "%",
	    Tooltip = "How strong the marker is drawn, keep it low to stay subtle."
	})
	Color = GoalESP:CreateColorSlider({
	    Name = "Color",
	    DefaultHue = 0.33
	})
end)

Run(function()
	local AutoCatch
	local Charge
	local ChargeLead
	local OwnKicks
	local Range
	local Horizon
	local Jump
	
	local Charged: boolean = false
	local Held: number?
	local NextCharge: number = 0
	local OldBegan, OldKick
	local HookBegan, HookKick
	
	local function GetArrival(State, LocalPosition: Vector3, WalkSpeed: number): number?
	    local Reach: number = Soccer.HitboxSettings.Receive.Size.Z * 0.5
	    for i: number = 0, 40 do
	        local Step: number = i * 0.05
	        local Position: Vector3 = Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, Step)
	        if ((Position - LocalPosition) * Vector3.new(1, 0, 1)).Magnitude <= WalkSpeed * Step + Reach then
	            return Step
	        end
	    end
	
	    return nil
	end
	
	AutoCatch = vape.Categories.Utility:CreateModule({
	    Name = "AutoCatch",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not HookBegan then
	                OldBegan = Soccer.ShootInput.HandleInputBegan
	                HookBegan = function(Input, ...)
	                    if Charged and not Held and typeof(Input) == "Instance" and Soccer.Controls.IsInput("Kick", Input) then
	                        Held = os.clock()
	                    end
	                    return OldBegan(Input, ...)
	                end
	                Soccer.ShootInput.HandleInputBegan = HookBegan
	            end
	
	            if not HookKick then
	                OldKick = Soccer.ActionCommands.Kick
	                HookKick = function(...)
	                    local Call = OldKick(...)
	                    if Charged and Held and Call and Call.ChargeSeconds then
	                        Call.ChargeSeconds = math.clamp(os.clock() - Held, Soccer.KickCore.Constants.MinimumChargeSeconds, Call.MaximumChargeSeconds or Soccer.KickCore.Constants.MaximumChargeSeconds)
	                    end
	                    return Call
	                end
	                Soccer.ActionCommands.Kick = HookKick
	            end
	
	            AutoCatch:Clean(RunService.PostSimulation:Connect(function()
	                if Charged and not Soccer.ShootInput.IsCharging() then
	                    Charged, Held = false, nil
	                end
	                if not Entity.isAlive then
	                    return
	                end
	
	                local _, State = GetBall()
	                if not State or Soccer.Renderer.GetMainMatchOwnerUserId() or Soccer.Ownership.IsWithinReceiveHitbox(Entity.character.Character, State.Position) then
	                    return
	                end
	                if not OwnKicks.Enabled and State.LastKickerUserId == LocalPlayer.UserId and workspace:GetServerTimeNow() - (State.FlightStartedAt or 0) < 1.5 then
	                    return
	                end
	
	                local Step, Position, NeedsJump = GetIntercept(State, Horizon.Value, Range.Value)
	                if not Position then
	                    return
	                end
	
	                local Humanoid: Humanoid = Entity.character.Humanoid
	                local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                local Flat: Vector3 = (Position - LocalPosition) * Vector3.new(1, 0, 1)
	                if Flat.Magnitude > 1 then
	                    MoveCharacter(Flat.Unit)
	                end
	
	                if NeedsJump and Jump.Enabled and Humanoid.FloorMaterial ~= Enum.Material.Air and Step <= math.sqrt(2 * Humanoid.JumpHeight / workspace.Gravity) then
	                    Humanoid.Jump = true
	                end
	
	                local Lead: number? = Step or GetArrival(State, LocalPosition, Humanoid.WalkSpeed)
	                if not Charge.Enabled or not Lead or Lead > ChargeLead.Value then
	                    return
	                end
	
	                local Look: Vector3 = (State.Position - LocalPosition) * Vector3.new(1, 0, 1)
	                if Look.Magnitude > 0.01 then
	                    Entity.character.RootPart.CFrame = CFrame.lookAt(LocalPosition, LocalPosition + Look.Unit)
	                end
	
	                if Charged or Soccer.ShootInput.IsCharging() or os.clock() < NextCharge then
	                    return
	                end
	
	                local Input = GetInput("Kick")
	                if not Input then
	                    return
	                end
	
	                Charged, NextCharge = true, os.clock() + 0.25
	                Soccer.ShootInput.HandleInputBegan(Input, false)
	            end))
	        else
	            if Soccer.ShootInput.HandleInputBegan == HookBegan then
	                Soccer.ShootInput.HandleInputBegan = OldBegan
	                HookBegan = nil
	            end
	            if Soccer.ActionCommands.Kick == HookKick then
	                Soccer.ActionCommands.Kick = OldKick
	                HookKick = nil
	            end
	            if Charged and not Held then
	                Soccer.ShootInput.CancelCharge()
	            end
	            Charged, Held, NextCharge = false, nil, 0
	        end
	    end,
	    Tooltip = "Reads where the ball is going, walks onto it and winds a kick up so it is ready the moment it reaches you."
	})
	
	Charge = AutoCatch:CreateToggle({
	    Name = "Charge",
	    Default = true,
	    Tooltip = "Turns you onto the ball and winds a kick up as it arrives, then holds it. The power is still yours, counted from the moment you hold kick yourself."
	})
	ChargeLead = AutoCatch:CreateSlider({
	    Name = "Charge lead",
	    Min = 0.05,
	    Max = 1.2,
	    Default = 0.4,
	    Decimal = 100,
	    Suffix = "s",
	    Tooltip = "How long before the ball reaches you that the kick starts winding up."
	})
	OwnKicks = AutoCatch:CreateToggle({
	    Name = "Own kicks",
	    Tooltip = "Also chases balls you kicked yourself, off by default so it stops eating your own passes and shots."
	})
	Range = AutoCatch:CreateSlider({
	    Name = "Range",
	    Min = 5,
	    Max = 90,
	    Default = 45,
	    Tooltip = "How far you will run to meet the ball."
	})
	Horizon = AutoCatch:CreateSlider({
	    Name = "Horizon",
	    Min = 0.5,
	    Max = 5,
	    Default = 2.5,
	    Decimal = 10,
	    Suffix = "s",
	    Tooltip = "How far ahead the balls flight is read."
	})
	Jump = AutoCatch:CreateToggle({
	    Name = "Jump",
	    Default = true,
	    Tooltip = "Jumps at the right moment for balls above your reach."
	})
end)

Run(function()
	local AutoGoalkeeper
	local Lead
	local Margin
	local Punch
	local PunchRange
	local Positioning
	local Follow
	local Jump
	local Rush
	local RushRange
	local Delay
	
	local NextDive: number = 0
	local NextPunch: number = 0
	local NextTackle: number = 0
	local DiveName: string?
	local Punching, PunchStart
	local Old: (...any) -> ...any
	local Hook: ((...any) -> ...any)?
	
	local function GetCrossing(State, Goal: BasePart)
	    if -State.Velocity:Dot(Goal.CFrame.LookVector) < 10 then
	        return nil
	    end
	
	    local Half: Vector3 = Goal.Size * 0.5
	    for i: number = 1, 60 do
	        local Step: number = i * 0.025
	        local Position: Vector3 = Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, Step)
	        local Offset: Vector3 = Goal.CFrame:PointToObjectSpace(Position)
	        if math.abs(Offset.X) <= Half.X + Margin.Value and Offset.Y <= Half.Y and Offset.Y >= -Half.Y - 4 and math.abs(Offset.Z) <= Half.Z + 8 then
	            return Step, Position
	        end
	    end
	
	    return nil
	end
	
	local function GetContact(Target, LocalPosition: Vector3)
	    local Velocity: Vector3 = Target.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	    local Ahead: number = -Soccer.HitboxSettings.SlideTackle.CFrameOffset.Z
	    local Slack: number = Soccer.HitboxSettings.SlideTackle.Size.X * 0.5
	    for i: number = 0, 12 do
	        local Step: number = Soccer.SlideTackle.Constants.HitboxDelaySeconds + i * 0.025
	        local Predicted: Vector3 = Target.RootPart.Position + Velocity * Step
	        local Flat: Vector3 = (Predicted - LocalPosition) * Vector3.new(1, 0, 1)
	        if math.abs(Flat.Magnitude - (Soccer.SlideTackle.GetTravel(Step) + Ahead)) <= Slack then
	            return Step, Predicted
	        end
	    end
	
	    return nil
	end
	
	local function IsKeeping(Goal: BasePart): boolean
	    if Soccer.GoalkeeperRole.IsGoalkeeper() then
	        return true
	    end
	    if IsKeepingHeld() then
	        return false
	    end
	
	    local Zone = Goal.Parent:FindFirstChild("Goalkeeper")
	    if not Zone then
	        return false
	    end
	
	    local Offset: Vector3 = Zone.CFrame:PointToObjectSpace(Entity.character.RootPart.Position)
	    return math.abs(Offset.X) <= Zone.Size.X * 0.5 and math.abs(Offset.Z) <= Zone.Size.Z * 0.5
	end
	
	local function GetAimed(Owner, Goal: BasePart): Vector3?
	    local Forward: Vector3? = Soccer.AimFacing.GetFlatDirection(Owner.RootPart.CFrame.LookVector)
	    local Facing: number = Forward and Forward:Dot(Goal.CFrame.LookVector) or 0
	    if Facing >= -0.05 then
	        return nil
	    end
	
	    return Owner.RootPart.Position + Forward * ((Goal.Position - Owner.RootPart.Position):Dot(Goal.CFrame.LookVector) / Facing)
	end
	
	AutoGoalkeeper = vape.Categories.Utility:CreateModule({
	    Name = "AutoGoalkeeper",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Hook then
	                Old = Soccer.GoalkeeperDive.GetDirectionChoice
	                Hook = function(MoveDirection: Vector3, CameraCFrame: CFrame, Forward: Vector3)
	                    if DiveName then
	                        return Soccer.GoalkeeperDive.GetDirectionChoiceByName(DiveName)
	                    end
	                    return Old(MoveDirection, CameraCFrame, Forward)
	                end
	                Soccer.GoalkeeperDive.GetDirectionChoice = Hook
	            end
	
	            AutoGoalkeeper:Clean(RunService.PreRender:Connect(function()
	                if not Entity.isAlive then
	                    return
	                end
	
	                local Goal = GetGoal(false)
	                if not Goal or not IsKeeping(Goal) then
	                    return
	                end
	                if Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) then
	                    if Punching then
	                        Soccer.ShootInput.HandleInputEnded(Punching, false)
	                        Punching = nil
	                    end
	                    return
	                end
	
	                local Owner = GetCarrier()
	                local Carried: Vector3? = Owner and (Soccer.Carry.GetOwnedPosition(Owner.Character) or Owner.RootPart.Position) or nil
	                local _, State = GetBall()
	                if not Owner and not State then
	                    return
	                end
	
	                local Humanoid: Humanoid = Entity.character.Humanoid
	                local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                local Step, Landing
	                if not Owner then
	                    Step, Landing = GetCrossing(State, Goal)
	                end
	
	                if Owner and Owner.Targetable and Rush.Enabled and ((Carried - Goal.Position) * Vector3.new(1, 0, 1)).Magnitude <= RushRange.Value then
	                    if Punching then
	                        Soccer.ShootInput.HandleInputEnded(Punching, false)
	                        Punching = nil
	                    end
	
	                    local Chase: Vector3 = (Carried - LocalPosition) * Vector3.new(1, 0, 1)
	                    local _, Predicted = GetContact(Owner, LocalPosition)
	                    local Input = Predicted and os.clock() >= NextTackle and not Soccer.Dodge.IsDribbling(Owner.Character) and GetInput("Tackle") or nil
	                    local Direction: Vector3? = Input and (Predicted - LocalPosition) * Vector3.new(1, 0, 1) or nil
	                    if Direction and Direction.Magnitude > 0.01 then
	                        Direction = Direction.Unit
	                        Entity.character.RootPart.CFrame = CFrame.lookAt(LocalPosition, LocalPosition + Direction)
	                        MoveCharacter(Direction)
	                        NextTackle = os.clock() + Soccer.SlideTackle.Constants.CooldownSeconds + Delay:GetRandomValue()
	                        Soccer.SlideTackleInput.HandleInputBegan(Input, false)
	                    elseif Chase.Magnitude > 1 then
	                        MoveCharacter(Chase.Unit)
	                    end
	                    return
	                end
	
	                if not Step then
	                    if Punching then
	                        Soccer.ShootInput.HandleInputEnded(Punching, false)
	                        Punching = nil
	                    end
	
	                    if Positioning.Enabled then
	                        local Target: Vector3 = Owner and (Follow.Enabled and Owner.Targetable and GetAimed(Owner, Goal) or Carried) or Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, 0.35)
	                        local Reach: number = math.clamp(Goal.CFrame.RightVector:Dot(Target - Goal.Position), -(Goal.Size.X * 0.5), Goal.Size.X * 0.5)
	                        local Stand: Vector3 = Goal.Position + Goal.CFrame.RightVector * Reach + Goal.CFrame.LookVector * (Goal.Size.Z * 0.5 + 4)
	                        local Move: Vector3 = Vector3.new(Stand.X, LocalPosition.Y, Stand.Z) - LocalPosition
	                        if Move.Magnitude > 1.5 then
	                            MoveCharacter(Move.Unit)
	                        end
	                    elseif IsCenterHeld() then
	                        local Stand: Vector3 = Goal.Position + Goal.CFrame.LookVector * (Goal.Size.Z * 0.5 + 4)
	                        local Move: Vector3 = Vector3.new(Stand.X, LocalPosition.Y, Stand.Z) - LocalPosition
	                        MoveCharacter(Move.Magnitude > 1.5 and Move.Unit or Vector3.zero)
	                    end
	                    return
	                end
	
	                local Crossing: number? = Soccer.GoalkeeperPrediction.GetPlaneTime(State, LocalPosition, Goal.CFrame.LookVector, 0)
	                local Aim: Vector3 = Crossing and Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, Crossing) or Landing
	                if Crossing then
	                    Step = Crossing
	                end
	
	                local Lateral: number = Goal.CFrame.RightVector:Dot(Aim - LocalPosition)
	                local Standing: number = Soccer.HitboxSettings.Receive.Size.Y * 0.5
	                local Rise: number = Aim.Y - LocalPosition.Y
	
	                if Jump.Enabled and Rise > Standing and math.abs(Lateral) <= Soccer.HitboxSettings.AirReceive.Size.X * 0.5 and Humanoid.FloorMaterial ~= Enum.Material.Air and Step <= math.sqrt(2 * Humanoid.JumpHeight / workspace.Gravity) then
	                    Humanoid.Jump = true
	                end
	
	                if Punch.Enabled and math.abs(Lateral) <= PunchRange.Value then
	                    local Move: Vector3 = (Aim - LocalPosition) * Vector3.new(1, 0, 1)
	                    if Move.Magnitude > 1 then
	                        MoveCharacter(Move.Unit)
	                    end
	
	                    if not Punching and Step <= 0.35 and os.clock() >= NextPunch then
	                        Punching = GetInput("Kick")
	                        if Punching then
	                            PunchStart = os.clock()
	                            Soccer.ShootInput.HandleInputBegan(Punching, false)
	                        end
	                    end
	
	                    if Punching and os.clock() - PunchStart >= Soccer.KickCore.Constants.MinimumChargeSeconds and (Step <= 0.05 or Soccer.Ownership.IsWithinReceiveHitbox(Entity.character.Character, State.Position)) then
	                        Soccer.ShootInput.HandleInputEnded(Punching, false)
	                        Punching = nil
	                        NextPunch = os.clock() + Soccer.Kick.Constants.CooldownSeconds
	                        NextDive = os.clock() + 0.5
	                    end
	                    return
	                end
	
	                if Positioning.Enabled then
	                    local Reach: number = math.clamp(Goal.CFrame.RightVector:Dot(Aim - Goal.Position), -(Goal.Size.X * 0.5), Goal.Size.X * 0.5)
	                    local Stand: Vector3 = Goal.Position + Goal.CFrame.RightVector * Reach + Goal.CFrame.LookVector * (Goal.Size.Z * 0.5 + 4)
	                    local Move: Vector3 = Vector3.new(Stand.X, LocalPosition.Y, Stand.Z) - LocalPosition
	                    if Move.Magnitude > 1.5 then
	                        MoveCharacter(Move.Unit)
	                    end
	                end
	
	                if os.clock() < NextDive or not Soccer.GoalkeeperRole.IsGoalkeeper() then
	                    return
	                end
	                if math.abs(Lateral) <= Soccer.HitboxSettings.Receive.Size.X * 0.5 then
	                    return
	                end
	
	                local Needed: number = Soccer.GoalkeeperDive.Constants.DurationSeconds
	                for i: number = 1, 60 do
	                    local Reach: number = i * 0.015
	                    if Soccer.GoalkeeperDive.GetTravel(Reach) >= math.abs(Lateral) then
	                        Needed = Reach
	                        break
	                    end
	                end
	                if Step > math.min(Needed + 0.06, Lead.Value) then
	                    return
	                end
	
	                local Wanted: Vector3 = Goal.CFrame.RightVector * Lateral
	                if Wanted.Magnitude < 0.01 then
	                    return
	                end
	
	                Wanted = Wanted.Unit
	                local Forward: Vector3 = Soccer.AimFacing.GetFlatDirection(Camera.CFrame.LookVector) or Vector3.new(0, 0, 1)
	                DiveName = Soccer.ActionMotion.GetDirectionName(Wanted:Dot(Forward), Wanted:Dot(Vector3.new(-Forward.Z, 0, Forward.X)))
	                NextDive = os.clock() + Soccer.GoalkeeperDive.Constants.RepeatDelaySeconds + Delay:GetRandomValue()
	                Soccer.GoalkeeperRole.Dive()
	                DiveName = nil
	            end))
	        else
	            if Soccer.GoalkeeperDive.GetDirectionChoice == Hook then
	                Soccer.GoalkeeperDive.GetDirectionChoice = Old
	                Hook = nil
	            end
	            if Punching then
	                Soccer.ShootInput.HandleInputEnded(Punching, false)
	                Punching = nil
	            end
	            NextDive = 0
	            NextPunch = 0
	            DiveName = nil
	        end
	    end,
	    Tooltip = "Keeps goal whenever you are in your own keeper zone, punching the shots you can reach and diving for the rest."
	})
	
	Lead = AutoGoalkeeper:CreateSlider({
	    Name = "Lead",
	    Min = 0.05,
	    Max = 1.5,
	    Default = 0.45,
	    Decimal = 100,
	    Suffix = "s",
	    Tooltip = "Caps how early you commit. The dive itself is timed off how far it has to travel."
	})
	Margin = AutoGoalkeeper:CreateSlider({
	    Name = "Margin",
	    Min = 0,
	    Max = 15,
	    Default = 5,
	    Tooltip = "How far outside the posts a shot can be before you stop going for it, width only."
	})
	Punch = AutoGoalkeeper:CreateToggle({
	    Name = "Punch",
	    Default = true,
	    Tooltip = "Walks into shots close enough to reach and punches them clear instead of diving."
	})
	PunchRange = AutoGoalkeeper:CreateSlider({
	    Name = "Punch range",
	    Min = 1,
	    Max = 20,
	    Default = 7,
	    Tooltip = "How far to the side a shot can be and still be walked into rather than dived at."
	})
	Positioning = AutoGoalkeeper:CreateToggle({
	    Name = "Positioning",
	    Default = true,
	    Tooltip = "Walks you along your line to stay in front of the ball. With this off, AutoPlay still holds you in the middle of the goal."
	})
	Follow = AutoGoalkeeper:CreateToggle({
	    Name = "Follow",
	    Default = true,
	    Tooltip = "Reads which part of the goal the player on the ball is lined up on and holds your line there before they shoot."
	})
	Jump = AutoGoalkeeper:CreateToggle({
	    Name = "Jump",
	    Default = true,
	    Tooltip = "Jumps for balls going in above your standing reach. A dive only lifts you 1.6 studs, so straight high shots cannot be dived at all."
	})
	Rush = AutoGoalkeeper:CreateToggle({
	    Name = "Rush",
	    Default = true,
	    Tooltip = "Comes off your line at an opponent dribbling the ball in and slide tackles it off them, instead of standing there while they walk it into the net."
	})
	RushRange = AutoGoalkeeper:CreateSlider({
	    Name = "Rush range",
	    Min = 5,
	    Max = 60,
	    Default = 30,
	    Tooltip = "How close to your goal a carrier has to get before you leave your line for them."
	})
	Delay = AutoGoalkeeper:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0,
	    DefaultMax = 0.1,
	    Decimal = 100
	})
end)

Run(function()
	local AutoPass
	local OnRequest
	local Range
	local Safety
	local Window
	local FreeAim
	local Delay
	
	local FlatMask: Vector3 = Vector3.new(1, 0, 1)
	local Samples: number = 16
	local Requests: {[number]: number} = {}
	local Curves = {}
	local NextPass: number = 0
	local PassPoint: Vector3?
	local Assisted
	local Old, OldAim
	local HookRay, HookAim
	
	local function Simulate(Alpha: number, Lob: boolean, Carry: number)
	    local Settings = Lob and Soccer.Pass.Constants.Lob or Soccer.Pass.Constants.Ground
	    local Kind = Lob and Soccer.KickCore.LaunchKinds.Lob or Soccer.KickCore.LaunchKinds.Pass
	    local Multiplier: number = Soccer.KickCore.GetLaunchMultiplier(Kind) or 1
	    local Speed: number = (Settings.MinimumSpeed + (Settings.MaximumSpeed - Settings.MinimumSpeed) * Alpha ^ Soccer.KickCore.Constants.PowerCurve) * Multiplier
	    local Rise: number = Lob and (Settings.MinimumUpwardSpeed + (Settings.MaximumUpwardSpeed - Settings.MinimumUpwardSpeed) * math.sqrt(Alpha)) * Multiplier or Speed * math.tan(math.rad(Settings.LaunchAngleDegrees))
	
	    local State = {Mode = "Airborne", Position = Vector3.new(0, 0, 0), Velocity = Vector3.new(0, Rise, math.max(Speed + Carry, 1)), Spin = Vector3.new(0, 0, 0), Radius = 1}
	    local Previous: Vector3 = Vector3.new(0, 0, 0)
	    for i: number = 1, 140 do
	        local Step: number = i * 0.02
	        local Position: Vector3 = Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, Step)
	        if Position.Y <= 0 then
	            local Fall: number = Previous.Y - Position.Y
	            local Ratio: number = Fall > 0.001 and Previous.Y / Fall or 0
	            return (Previous * FlatMask).Magnitude + ((Position - Previous) * FlatMask).Magnitude * Ratio, Step - 0.02 * (1 - Ratio)
	        end
	        Previous = Position
	    end
	
	    return (Previous * FlatMask).Magnitude, 2.8
	end
	
	local function GetCurve(Lob: boolean, Carry: number)
	    local Kind = Lob and Soccer.KickCore.LaunchKinds.Lob or Soccer.KickCore.LaunchKinds.Pass
	    local Bucket: number = math.round(Carry * 0.5)
	    local Key: string = `{Kind}{Bucket}_{Soccer.KickCore.GetLaunchMultiplier(Kind) or 1}`
	    local Curve = Curves[Key]
	    if Curve then
	        return Curve
	    end
	
	    Curve = table.create(Samples + 1)
	    for i: number = 0, Samples do
	        local Reach, Flight = Simulate(i / Samples, Lob, Bucket * 2)
	        Curve[i + 1] = {Reach = Reach, Flight = Flight}
	    end
	    Curves[Key] = Curve
	
	    return Curve
	end
	
	local function GetPower(Distance: number, Lob: boolean, Carry: number)
	    local Curve = GetCurve(Lob, Carry)
	    local Top = Curve[Samples + 1]
	    if Distance >= Top.Reach then
	        return 1, Top.Flight, Top.Reach
	    end
	    if Distance <= Curve[1].Reach then
	        return 0, Curve[1].Flight, Curve[1].Reach
	    end
	
	    for i: number = 2, Samples + 1 do
	        local Point = Curve[i]
	        if Point.Reach >= Distance then
	            local Previous = Curve[i - 1]
	            local Span: number = Point.Reach - Previous.Reach
	            local Ratio: number = Span > 0.001 and (Distance - Previous.Reach) / Span or 0
	            return (i - 2 + Ratio) / Samples, Previous.Flight + (Point.Flight - Previous.Flight) * Ratio, Distance
	        end
	    end
	
	    return 1, Top.Flight, Top.Reach
	end
	
	local function GetHorizon(Flight: number): number
	    return Flight + math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.4)
	end
	
	local function GetLead(Origin: Vector3, Entity, Speed: number, Horizon: number): Vector3
	    local Root: BasePart = Entity.RootPart
	    local Position: Vector3 = Root.Position
	    if Speed <= 0.01 or Horizon <= 0.01 then
	        return Position
	    end
	
	    local Velocity: Vector3 = Root.AssemblyLinearVelocity
	    local _, Impact, Travel = PredictionLib.SolveTrajectory(Origin, Speed, 0, Position, Velocity, workspace.Gravity, Entity.HipHeight, nil, nil, math.abs(Velocity.Y) > 0.01, Position, Root, nil, true)
	    if not Impact or not Travel or Travel <= 0.01 then
	        return Position
	    end
	
	    local Reached: number = PredictionLib.getLatency() + Travel
	    local Scaled: Vector3 = Position + (Impact - Position) * (Reached > 0.01 and Horizon / Reached or 1)
	
	    return Vector3.new(Scaled.X, Position.Y, Scaled.Z)
	end
	
	local function SolveMode(Origin: Vector3, Entity, Lob: boolean, Inherited: Vector3)
	    local Target: Vector3 = Entity.RootPart.Position
	    local Alpha, Flight, Reach, Speed
	    for i: number = 1, 4 do
	        local Offset: Vector3 = (Target - Origin) * FlatMask
	        local Distance: number = Offset.Magnitude
	        Alpha, Flight, Reach = GetPower(Distance, Lob, Distance > 0.01 and Inherited:Dot(Offset.Unit) or 0)
	        Speed = Flight > 0.01 and Reach / Flight or 0
	        if i == 4 then
	            break
	        end
	
	        local Lead: Vector3 = GetLead(Origin, Entity, Speed, GetHorizon(Flight))
	        local Settled: boolean = (Lead - Target).Magnitude < 0.25
	        Target = Lead
	        if Settled then
	            break
	        end
	    end
	
	    return Target, Alpha, Flight, Reach, Speed
	end
	
	local function GetSolution(Origin: Vector3, Entity, Blocked: boolean, Inherited: Vector3)
	    local Straight: number = ((Entity.RootPart.Position - Origin) * FlatMask).Magnitude
	    local Lob: boolean = Straight > GetCurve(false, 0)[Samples + 1].Reach or (Blocked and Straight >= GetCurve(true, 0)[1].Reach)
	    local Target, Alpha, Flight, Reach, Speed = SolveMode(Origin, Entity, Lob, Inherited)
	    if not Lob and ((Target - Origin) * FlatMask).Magnitude > Reach then
	        Lob = true
	        Target, Alpha, Flight, Reach, Speed = SolveMode(Origin, Entity, true, Inherited)
	    end
	
	    return Target, Lob, Alpha, Reach, Speed, Flight
	end
	
	local function IsClear(From: Vector3, To: Vector3): boolean
	    local Direction: Vector3 = To - From
	    local Length: number = Direction.Magnitude
	    if Length < 0.01 then
	        return false
	    end
	
	    Direction = Direction.Unit
	    for _, v: any in Entity.List do
	        if v.Targetable then
	            local Offset: Vector3 = v.RootPart.Position - From
	            if (Offset - Direction * math.clamp(Offset:Dot(Direction), 0, Length)).Magnitude < Safety.Value then
	                return false
	            end
	        end
	    end
	
	    return true
	end
	
	local function GetPressure(Position: Vector3, Radius: number): number
	    local Count: number = 0
	    for _, v: any in Entity.List do
	        if v.Targetable and (v.RootPart.Position - Position).Magnitude <= Radius then
	            Count += 1
	        end
	    end
	
	    return Count
	end
	
	local function GetTarget(Origin: Vector3)
	    local Team: string? = Soccer.ActorTeams.GetActorTeamName(LocalPlayer)
	    if not Team then
	        return nil
	    end
	
	    local Goal = GetGoal(true)
	    local Zone = Goal and Goal.Parent:FindFirstChild("Goalkeeper") or nil
	    local Inherited: Vector3 = Soccer.KickCore.GetInheritedVelocity(Entity.character.Character) * FlatMask
	    local Best, BestScore
	    for _, v: any in Entity.List do
	        if not v.Targetable and Soccer.ActorTeams.GetCharacterTeamName(v.Character) == Team then
	            local Resting: Vector3 = v.RootPart.Position
	            local Target, Lob, Alpha, Reach, Speed, Flight = GetSolution(Origin, v, not IsClear(Origin, Resting), Inherited)
	            local Distance: number = ((Target - Origin) * FlatMask).Magnitude
	            local Asked = v.Player and Requests[v.Player.UserId] and os.clock() - Requests[v.Player.UserId] <= Window.Value
	            if Distance <= Range.Value and Distance >= 8 and (Asked or not OnRequest.Enabled) and (Lob or IsClear(Origin, Target)) then
	                local Score: number = (Asked and 120 or 0) - Distance * 0.2 - math.max(Distance - Reach, 0) * 4 - GetPressure(Target, Safety.Value * 2) * 25
	                if Goal then
	                    Score += (Goal.Position - Origin).Magnitude - (Goal.Position - Target).Magnitude
	                end
	                local Offset: Vector3? = Zone and Zone.CFrame:PointToObjectSpace(Target) or nil
	                if Offset and math.abs(Offset.X) <= Zone.Size.X * 0.5 and math.abs(Offset.Z) <= Zone.Size.Z * 0.5 then
	                    Score += 200
	                end
	                if not BestScore or Score > BestScore then
	                    Best, BestScore = {Entity = v, Point = Target, Lob = Lob, Alpha = Alpha, Speed = Speed, Flight = Flight}, Score
	                end
	            end
	        end
	    end
	
	    return Best
	end
	
	local function GetDirection(): Vector3?
	    local Origin: Vector3? = GetOwnedPosition()
	    local Wanted: Vector3? = Origin and (PassPoint - Origin) * FlatMask or nil
	    if not Wanted or Wanted.Magnitude < 0.01 then
	        return nil
	    end
	
	    return Wanted.Unit
	end
	
	AutoPass = vape.Categories.Utility:CreateModule({
	    Name = "AutoPass",
	    Function = function(Callback: boolean)
	        if Callback then
	            if FreeAim.Enabled then
	                Assisted = Soccer.PlayerSettings.GetLocal(Soccer.PlayerSettings.Names.AssistedPasses)
	                Soccer.PlayerSettings.SetLocal(Soccer.PlayerSettings.Names.AssistedPasses, false)
	            end
	
	            if not HookRay then
	                Old = Soccer.Reticle.GetCameraRay
	                HookRay = function(...)
	                    local Call = Old(...)
	                    if not PassPoint then
	                        return Call
	                    end
	
	                    local Wanted: Vector3? = GetDirection()
	                    if not Wanted then
	                        return Call
	                    end
	
	                    return Ray.new(Call.Origin, Wanted * Call.Direction.Magnitude)
	                end
	
	                Soccer.Reticle.GetCameraRay = HookRay
	            end
	
	            if not HookAim then
	                OldAim = Soccer.Reticle.GetCameraAimRayWithoutHit
	                HookAim = function(...)
	                    local Call = OldAim(...)
	                    if not PassPoint or typeof(Call) ~= "table" or not Call.Direction then
	                        return Call
	                    end
	
	                    local Wanted: Vector3? = GetDirection()
	                    if not Wanted then
	                        return Call
	                    end
	
	                    Call.Direction = Wanted
	                    if typeof(Call.CameraCFrame) == "CFrame" then
	                        Call.CameraCFrame = CFrame.lookAt(Call.CameraCFrame.Position, Call.CameraCFrame.Position + Wanted)
	                    end
	
	                    return Call
	                end
	
	                Soccer.Reticle.GetCameraAimRayWithoutHit = HookAim
	            end
	
	            AutoPass:Clean(ReplicatedStorage.Remotes.Ball.CallForPassEffect.OnClientEvent:Connect(function(UserId: number)
	                Requests[UserId] = os.clock()
	            end))
	
	            repeat
	                task.wait()
	                if not Entity.isAlive or os.clock() < NextPass or IsPassHeld() then
	                    continue
	                end
	                if not Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) then
	                    continue
	                end
	
	                local Origin: Vector3? = GetOwnedPosition()
	                local Solution = Origin and GetTarget(Origin) or nil
	                local Input = Solution and GetInput(Solution.Lob and "Lob" or "Pass") or nil
	                if not Input then
	                    continue
	                end
	
	                local PassType = Solution.Lob and Soccer.ActionCommands.PassTypes.FreeLobPass or Soccer.ActionCommands.PassTypes.FreeLowPass
	                local Release: number = os.clock() + Soccer.Pass.GetChargeSecondsFromAlpha(Solution.Alpha, Entity.character.Character, PassType)
	                PassPoint = Solution.Point
	                Soccer.PassInput.HandleInputBegan(Input, false)
	
	                repeat
	                    task.wait()
	                    if not Entity.isAlive or not Solution.Entity.RootPart.Parent then
	                        break
	                    end
	
	                    local Moved: Vector3? = GetOwnedPosition()
	                    PassPoint = Moved and GetLead(Moved, Solution.Entity, Solution.Speed, GetHorizon(Solution.Flight)) or PassPoint
	                until os.clock() >= Release
	
	                Soccer.PassInput.HandleInputEnded(Input, false)
	                PassPoint = nil
	                NextPass = os.clock() + Delay:GetRandomValue()
	            until not AutoPass.Enabled
	        else
	            if Assisted ~= nil then
	                Soccer.PlayerSettings.SetLocal(Soccer.PlayerSettings.Names.AssistedPasses, Assisted)
	                Assisted = nil
	            end
	
	            if Soccer.Reticle.GetCameraRay == HookRay then
	                Soccer.Reticle.GetCameraRay = Old
	                HookRay = nil
	            end
	            if Soccer.Reticle.GetCameraAimRayWithoutHit == HookAim then
	                Soccer.Reticle.GetCameraAimRayWithoutHit = OldAim
	                HookAim = nil
	            end
	            PassPoint = nil
	            NextPass = 0
	            table.clear(Requests)
	            table.clear(Curves)
	        end
	    end,
	    Tooltip = "Passes to the best placed teammate, lobbing over anyone in the way and weighting the pass for the distance."
	})
	
	OnRequest = AutoPass:CreateToggle({
	    Name = "Only on request",
	    Default = true,
	    Tooltip = "Only passes when a teammate actually calls for it."
	})
	Range = AutoPass:CreateSlider({
	    Name = "Range",
	    Min = 10,
	    Max = 160,
	    Default = 90,
	    Tooltip = "How far away a teammate can be to get the ball."
	})
	Safety = AutoPass:CreateSlider({
	    Name = "Safety",
	    Min = 1,
	    Max = 25,
	    Default = 8,
	    Tooltip = "How close an opponent may get to the pass before the lane counts as blocked and it lobs instead."
	})
	Window = AutoPass:CreateSlider({
	    Name = "Request window",
	    Min = 0.5,
	    Max = 8,
	    Default = 3,
	    Decimal = 10,
	    Suffix = "s",
	    Tooltip = "How long a teammates call for the ball stays worth answering."
	})
	FreeAim = AutoPass:CreateToggle({
	    Name = "Free aim",
	    Default = true,
	    Tooltip = "Turns the games own pass assist off while this runs. The assist aims at where your teammate is standing and throws the lead away, so leave this on."
	})
	Delay = AutoPass:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 2,
	    DefaultMin = 0.1,
	    DefaultMax = 0.25,
	    Decimal = 100
	})
end)

Run(function()
	local AutoPlay
	local Drive
	local Sprinting
	local Look
	local LookSpeed
	local Range
	local Window
	local Squeeze
	local Tether
	local Avoid
	local MineDistance
	local Safety
	local Spread
	local Delay
	
	local FlatMask: Vector3 = Vector3.new(1, 0, 1)
	local ShotReach: number = 65
	local OilReach: number = 4.5
	local Partners: {string} = {"AutoGoalkeeper", "AutoDribble", "AutoTackle", "AutoPass", "ShotRedirect", "Anti-AFK"}
	local Restore: {[string]: boolean} = {}
	local Requests: {[number]: number} = {}
	local Oil = {}
	local Hazards = {}
	local OilGeneration: number = 0
	local NextRequest: number = 0
	local NextShot: number = 0
	local Charging, ChargeStart
	local Keeper, Playing, Sprinted, Watching
	
	local function GetPressure(Position: Vector3, Radius: number): number
	    local Count: number = 0
	    for _, v: any in Entity.List do
	        if v.Targetable and (v.RootPart.Position - Position).Magnitude <= Radius then
	            Count += 1
	        end
	    end
	
	    return Count
	end
	
	local function IsClear(From: Vector3, To: Vector3, Ignore): boolean
	    local Direction: Vector3 = To - From
	    local Length: number = Direction.Magnitude
	    if Length < 0.01 then
	        return false
	    end
	
	    Direction = Direction.Unit
	    for _, v: any in Entity.List do
	        if v.Targetable and v ~= Ignore then
	            local Offset: Vector3 = v.RootPart.Position - From
	            if (Offset - Direction * math.clamp(Offset:Dot(Direction), 0, Length)).Magnitude < Safety.Value then
	                return false
	            end
	        end
	    end
	
	    return true
	end
	
	local function IsTeammate(Ent, Team: string): boolean
	    return not Ent.Targetable and Ent.Character.Parent ~= nil and Soccer.ActorTeams.GetCharacterTeamName(Ent.Character) == Team
	end
	
	local function GetMouth(Goal: BasePart, Origin: Vector3)
	    local Normal: Vector3 = (Goal.CFrame.LookVector * FlatMask).Unit
	    if ((Goal.Position - Origin) * FlatMask):Dot(Normal) < 0 then
	        Normal = -Normal
	    end
	
	    return Goal.Position - Normal * (Goal.Size.Z * 0.5), Normal
	end
	
	local function GetContained(Position: Vector3): Vector3
	    local Walls = workspace.Map.Data.Walls
	    local X: number = math.abs(Walls.Left.Position.X) - 3
	    local Z: number = math.abs(Walls.Back.Position.Z) - 3
	
	    return Vector3.new(math.clamp(Position.X, -X, X), Position.Y, math.clamp(Position.Z, -Z, Z))
	end
	
	local function IsOilCurrent(Generation): boolean
	    if type(Generation) ~= "number" or Generation < OilGeneration then
	        return false
	    end
	    if Generation > OilGeneration then
	        OilGeneration = Generation
	        table.clear(Oil)
	    end
	
	    return true
	end
	
	local function AddOil(Patches)
	    local Fields = Soccer.OilSpill.PatchFields
	    for _, v: any in Patches or {} do
	        Oil[v[Fields.Id]] = {Position = v[Fields.Position], TeamName = v[Fields.TeamName], ExpiresAt = v[Fields.ExpiresAt]}
	    end
	end
	
	local function TrackOil(Effect)
	    local Spill = Soccer.OilSpill
	    local Kind = type(Effect) == "table" and Effect.Kind or nil
	    if Kind ~= Spill.PatchClearEffectKind and Kind ~= Spill.PatchRemoveEffectKind and Kind ~= Spill.PatchCheckpointEffectKind and Kind ~= Spill.PatchSnapshotEffectKind then
	        return
	    end
	    if not IsOilCurrent(Effect.Generation) then
	        return
	    end
	
	    if Kind == Spill.PatchClearEffectKind then
	        table.clear(Oil)
	    elseif Kind == Spill.PatchRemoveEffectKind then
	        for _, v: any in Effect.Patches or {} do
	            Oil[v[Spill.PatchRemovalFields.Id]] = nil
	        end
	    else
	        AddOil(Effect.Patches)
	    end
	end
	
	local function GetHazards(Team: string)
	    table.clear(Hazards)
	    if not Avoid.Enabled then
	        return
	    end
	
	    local Now: number = workspace:GetServerTimeNow()
	    for Id: any, v: {Position: Vector3, TeamName: string, ExpiresAt: number} in Oil do
	        if v.ExpiresAt <= Now then
	            Oil[Id] = nil
	        elseif v.TeamName ~= Team then
	            table.insert(Hazards, {Position = v.Position, Radius = OilReach, Soft = true})
	        end
	    end
	
	    for _, v: Instance in workspace.Misc.Items:GetChildren() do
	        if v:GetAttribute("PlacedItemId") == Soccer.ItemIds.Landmines and v:GetAttribute("PlacementContext") == "Match" then
	            table.insert(Hazards, {Position = v:GetPivot().Position, Radius = MineDistance.Value})
	        end
	    end
	end
	
	local function IsAvoided(Hazard, Destination: Vector3): boolean
	    return not (Hazard.Soft and ((Destination - Hazard.Position) * FlatMask).Magnitude < Hazard.Radius)
	end
	
	local function GetClearance(From: Vector3, Direction: Vector3, Length: number, Destination: Vector3): number
	    local Clearance: number = math.huge
	    for _, v: {Position: Vector3, Radius: number, Soft: boolean?} in Hazards do
	        if IsAvoided(v, Destination) then
	            local Offset: Vector3 = (v.Position - From) * FlatMask
	            local Along: number = math.clamp(Offset:Dot(Direction), 0, Length)
	            Clearance = math.min(Clearance, (Offset - Direction * Along).Magnitude - v.Radius)
	        end
	    end
	
	    return Clearance
	end
	
	local function Steer(Direction: Vector3, Destination: Vector3)
	    if Direction.Magnitude < 0.01 or #Hazards == 0 then
	        MoveCharacter(Direction)
	        return
	    end
	
	    local From: Vector3 = Entity.character.RootPart.Position
	    for _, v: {Position: Vector3, Radius: number, Soft: boolean?} in Hazards do
	        local Offset: Vector3 = (From - v.Position) * FlatMask
	        if Offset.Magnitude < v.Radius and Offset.Magnitude > 0.1 and IsAvoided(v, Destination) then
	            MoveCharacter(Offset.Unit)
	            return
	        end
	    end
	
	    local Length: number = math.min(((Destination - From) * FlatMask).Magnitude, 24)
	    local Best, BestClear = Direction, GetClearance(From, Direction, Length, Destination)
	    for i: number = 1, 6 do
	        if BestClear >= 0 then
	            break
	        end
	        for _, Side: number in {1, -1} do
	            local Candidate: Vector3 = CFrame.Angles(0, Side * i * math.rad(20), 0):VectorToWorldSpace(Direction)
	            local Clear: number = GetClearance(From, Candidate, Length, Destination)
	            if Clear > BestClear then
	                Best, BestClear = Candidate, Clear
	            end
	        end
	    end
	
	    MoveCharacter(Best)
	end
	
	local function GetShotScore(Position: Vector3, Mouth: Vector3, Normal: Vector3): number
	    local Flat: Vector3 = (Mouth - Position) * FlatMask
	    local Distance: number = Flat.Magnitude
	    if Distance < 1 then
	        return 0
	    end
	
	    local Score: number = math.min(Range.Value - Distance, 60) + Flat.Unit:Dot(Normal) * 35
	    Score -= GetPressure(Position, Squeeze.Value) * 22
	
	    return IsClear(Position, Mouth, Keeper) and Score or Score - 45
	end
	
	local function GetSpacing(Position: Vector3, Team: string, Linked: boolean): number
	    local Score, Nearest = 0, math.huge
	    for _, v: any in Entity.List do
	        local Distance: number = ((v.RootPart.Position - Position) * FlatMask).Magnitude
	        if v.Targetable then
	            Score -= math.max(Squeeze.Value - Distance, 0) * 3
	        elseif Linked and IsTeammate(v, Team) and not v.Character:GetAttribute("ActiveGoalkeeper") then
	            Nearest = math.min(Nearest, Distance)
	        end
	    end
	
	    if Nearest < math.huge then
	        Score -= math.max(Nearest - Tether.Value, 0) * 1.5 + math.max(8 - Nearest, 0) * 3
	    end
	
	    for _, v: {Position: Vector3, Radius: number, Soft: boolean?} in Hazards do
	        if ((v.Position - Position) * FlatMask).Magnitude < v.Radius then
	            Score -= 40
	        end
	    end
	
	    return Score
	end
	
	local function GetBetterSpot(Origin: Vector3, Mouth: Vector3, Normal: Vector3, Team: string, From: Vector3?): Vector3?
	    local Best, BestScore = nil, GetShotScore(Origin, Mouth, Normal) + GetSpacing(Origin, Team, From ~= nil) + (From and IsClear(From, Origin) and 25 or 0)
	    for i: number = 1, 12 do
	        local Angle: number = i * (math.pi / 6)
	        local Spot: Vector3 = GetContained(Origin + Vector3.new(math.cos(Angle), 0, math.sin(Angle)) * Spread.Value)
	        local Score: number = GetShotScore(Spot, Mouth, Normal) + GetSpacing(Spot, Team, From ~= nil) + (From and (IsClear(From, Spot) and 25 or -25) or 0)
	        if Score > BestScore then
	            Best, BestScore = Spot, Score
	        end
	    end
	
	    return Best
	end
	
	local function GetRequester(Origin: Vector3, Mouth: Vector3, Normal: Vector3, Team: string)
	    local Passing = vape.Modules.AutoPass
	    if not Passing or not Passing.Enabled then
	        return nil
	    end
	
	    local Best, BestScore
	    for _, v: any in Entity.List do
	        local Asked: number? = v.Player and Requests[v.Player.UserId] or nil
	        if Asked and os.clock() - Asked <= Window.Value and IsTeammate(v, Team) then
	            local Position: Vector3 = v.RootPart.Position
	            local Distance: number = ((Position - Origin) * FlatMask).Magnitude
	            if Distance >= 8 and Distance <= Passing.Options.Range.Value then
	                local Score: number = GetShotScore(Position, Mouth, Normal) + (IsClear(Origin, Position) and 20 or -20)
	                if not BestScore or Score > BestScore then
	                    Best, BestScore = v, Score
	                end
	            end
	        end
	    end
	
	    return Best, BestScore
	end
	
	local function IsNearest(Position: Vector3, Team: string): boolean
	    local Mine: number = (Position - Entity.character.RootPart.Position).Magnitude
	    for _, v: any in Entity.List do
	        if IsTeammate(v, Team) and (Position - v.RootPart.Position).Magnitude < Mine - 5 then
	            return false
	        end
	    end
	
	    return true
	end
	
	local function CancelShot()
	    if not Charging then
	        return
	    end
	
	    Charging = nil
	    Soccer.ShootInput.CancelCharge()
	end
	
	local function Shoot()
	    if Charging then
	        if os.clock() - ChargeStart < Soccer.KickCore.Constants.MaximumChargeSeconds then
	            return
	        end
	
	        Soccer.ShootInput.HandleInputEnded(Charging, false)
	        Charging = nil
	        NextShot = os.clock() + Soccer.Kick.Constants.CooldownSeconds + Delay:GetRandomValue()
	        return
	    end
	
	    local Input = os.clock() >= NextShot and GetInput("Kick") or nil
	    if not Input then
	        return
	    end
	
	    Charging, ChargeStart = Input, os.clock()
	    Soccer.ShootInput.HandleInputBegan(Input, false)
	end
	
	local function Request()
	    if os.clock() < NextRequest or not Soccer.CallForPass.CanCallForPass() then
	        return
	    end
	
	    local Input = GetInput("Request")
	    if not Input then
	        return
	    end
	
	    NextRequest = os.clock() + 1.5 + Delay:GetRandomValue()
	    Soccer.CallForPass.HandleInputBegan(Input, false)
	end
	
	local function Carry(Origin: Vector3, Mouth: Vector3, Normal: Vector3, Team: string, Keeping: boolean)
	    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	    local Target, Theirs = GetRequester(Origin, Mouth, Normal, Team)
	    local Pressured: boolean = GetPressure(Origin, Squeeze.Value) > 0
	
	    if Target and (Keeping or Pressured or Theirs > GetShotScore(Origin, Mouth, Normal) + 15) then
	        CancelShot()
	    else
	        HoldPasses(0.3)
	        local Distance: number = ((Mouth - Origin) * FlatMask).Magnitude - Entity.character.Humanoid.WalkSpeed * Soccer.KickCore.Constants.MaximumChargeSeconds
	        local Open: boolean = Distance <= Range.Value and IsClear(Origin, Mouth, Keeper)
	        if Open or (Charging or Pressured) and Distance <= math.max(Range.Value, ShotReach) then
	            Shoot()
	        else
	            CancelShot()
	        end
	    end
	
	    local Spot: Vector3 = GetBetterSpot(LocalPosition, Mouth, Normal, Team) or Mouth
	    local DriveDirection: Vector3 = (Spot - LocalPosition) * FlatMask
	    Steer(DriveDirection.Magnitude > 1.5 and DriveDirection.Unit or Vector3.zero, Spot)
	end
	
	local function Support(Mouth: Vector3, Normal: Vector3, Team: string, From: Vector3)
	    HoldPasses(0.3)
	
	    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	    local Spot: Vector3 = GetBetterSpot(LocalPosition, Mouth, Normal, Team, From) or LocalPosition
	    local Move: Vector3 = (Spot - LocalPosition) * FlatMask
	    Steer(Move.Magnitude > 1.5 and Move.Unit or Vector3.zero, Spot)
	    Request()
	end
	
	local function GetThrow(Carrier, Goal: BasePart): Vector3
	    local From: Vector3 = Carrier.RootPart.Position
	    local Own = GetGoal(false)
	    local Forward: Vector3 = ((Own.Position - Goal.Position) * FlatMask).Unit
	    local Facing: Vector3 = Soccer.AimFacing.GetFlatDirection(Carrier.RootPart.CFrame.LookVector) or Forward
	    local Constants = Soccer.GoalkeeperActions.Constants
	    local Holding: boolean = Soccer.Carry.IsCarriedInHands(Carrier.Character)
	    local Reach: number = Holding and Constants.ClearDistance or 90
	    local Best, BestDot = nil, math.cos(math.rad(Holding and Constants.ForcedClearMaximumAngleDegrees or 45))
	    for _, v: any in Entity.List do
	        if v.Targetable and v ~= Carrier then
	            local Offset: Vector3 = (v.RootPart.Position - From) * FlatMask
	            local Distance: number = Offset.Magnitude
	            if Distance > 8 and Distance <= Reach then
	                local Dot: number = Offset.Unit:Dot(Facing)
	                if Dot > BestDot then
	                    Best, BestDot = v.RootPart.Position - Offset.Unit * 5, Dot
	                end
	            end
	        end
	    end
	
	    local Shot: Vector3 = (Own.Position - From) * FlatMask
	    if not Holding and Shot.Magnitude > 1 and Shot.Magnitude <= ShotReach and Shot.Unit:Dot(Facing) > BestDot then
	        Best = From + Shot.Unit * math.min(12, Shot.Magnitude * 0.5)
	    end
	    if Best then
	        return Best
	    end
	
	    if Holding then
	        return GetContained(From + Soccer.GoalkeeperActions.ClampDirectionToClearCone(Facing, Forward) * Constants.ClearDistance)
	    end
	
	    return GetContained(From + Facing * 10)
	end
	
	local function Anticipate(Carrier, Goal: BasePart)
	    HoldPasses(0.3)
	
	    local Target: Vector3 = GetThrow(Carrier, Goal)
	    local Move: Vector3 = (Target - Entity.character.RootPart.Position) * FlatMask
	    Steer(Move.Magnitude > 2 and Move.Unit or Vector3.zero, Target)
	end
	
	local function Chase(State)
	    HoldPasses(0.3)
	
	    local _, Position = GetIntercept(State, 2.5, 200)
	    local Aim: Vector3 = Position or Soccer.GoalkeeperPrediction.GetBallPositionAtTime(State, 0.25)
	    local Move: Vector3 = (Aim - Entity.character.RootPart.Position) * FlatMask
	    Steer(Move.Magnitude > 1 and Move.Unit or Vector3.zero, Aim)
	end
	
	local function AimCamera(Delta: number)
	    if not Playing or not Look.Enabled or not Watching or not Entity.isAlive then
	        return
	    end
	
	    local Focus: Vector3 = Camera.Focus.Position
	    local Offset: Vector3 = Watching - Focus
	    local Flat: Vector3 = Offset * FlatMask
	    if Flat.Magnitude < 1 then
	        return
	    end
	
	    local Pitch: number = math.clamp(math.atan2(Offset.Y, Flat.Magnitude) - math.rad(10), math.rad(-45), math.rad(20))
	    local Wanted: Vector3 = CFrame.fromOrientation(Pitch, math.atan2(-Flat.X, -Flat.Z), 0).LookVector
	    local LookDirection: Vector3 = Camera.CFrame.LookVector:Lerp(Wanted, math.min(LookSpeed.Value * Delta, 1))
	    if LookDirection.Magnitude < 0.01 then
	        return
	    end
	
	    Camera.CFrame = CFrame.lookAt(Focus - LookDirection.Unit * (Camera.CFrame.Position - Focus).Magnitude, Focus)
	end
	
	local function Step()
	    local Keeping: boolean = Soccer.GoalkeeperRole.IsGoalkeeper()
	    if not Keeping then
	        HoldKeeping(0.3)
	    end
	
	    if not Entity.isAlive or not Soccer.Lobby.IsInMatch() or not Soccer.KickoffFreeze.IsPlayLive() then
	        CancelShot()
	        if Playing then
	            Playing = false
	            StopCharacter()
	        end
	        return
	    end
	
	    local Team: string? = Soccer.ActorTeams.GetActorTeamName(LocalPlayer)
	    local Goal = Team and GetGoal(true) or nil
	    if not Goal then
	        CancelShot()
	        return
	    end
	
	    Playing = true
	    Keeper = GetKeeper(Goal)
	    GetHazards(Team)
	    if Sprinting.Enabled and not Soccer.SprintInput.IsSprintButtonToggled() and Soccer.SprintInput.IsSprintButtonUsable() then
	        Soccer.SprintInput.ToggleSprintButton()
	        Sprinted = true
	    end
	
	    local Origin: Vector3 = GetOwnedPosition() or Entity.character.RootPart.Position
	    local Mouth, Normal = GetMouth(Goal, Origin)
	    if Soccer.Renderer.GetBallOwnedBy(LocalPlayer.UserId) then
	        Watching = Mouth
	        Carry(Origin, Mouth, Normal, Team, Keeping)
	        return
	    end
	
	    Watching = Soccer.Renderer.GetMainMatchPosition()
	    CancelShot()
	
	    if Keeping then
	        HoldPasses(0.3)
	        HoldCenter(0.3)
	        return
	    end
	
	    local Carrier = GetCarrier()
	    if Carrier then
	        if IsTeammate(Carrier, Team) then
	            Support(Mouth, Normal, Team, Carrier.RootPart.Position)
	        else
	            Anticipate(Carrier, Goal)
	        end
	        return
	    end
	
	    local _, State = GetBall()
	    if not State then
	        HoldPasses(0.3)
	        StopCharacter()
	        return
	    end
	
	    if IsNearest(State.Position, Team) then
	        Chase(State)
	        return
	    end
	
	    Support(Mouth, Normal, Team, State.Position)
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
	    Name = "AutoPlay",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Drive.Enabled then
	                for _, v: string in Partners do
	                    local Module = vape.Modules[v]
	                    if Module then
	                        Restore[v] = Module.Enabled
	                        if not Module.Enabled then
	                            Module:Toggle()
	                        end
	                    end
	                end
	            end
	
	            AutoPlay:Clean(ReplicatedStorage.Remotes.Ball.CallForPassEffect.OnClientEvent:Connect(function(UserId: number)
	                Requests[UserId] = os.clock()
	            end))
	            AutoPlay:Clean(ReplicatedStorage.Remotes.Items.OilPatches.OnClientEvent:Connect(function(Generation, Patches)
	                if IsOilCurrent(Generation) then
	                    AddOil(Patches)
	                end
	            end))
	            AutoPlay:Clean(ReplicatedStorage.Remotes.Items.Effect.OnClientEvent:Connect(TrackOil))
	            AutoPlay:Clean(RunService.PostSimulation:Connect(Step))
	
	            local BindKey: string = game:GetService("HttpService"):GenerateGUID(true)
	            RunService:BindToRenderStep(BindKey, Enum.RenderPriority.Camera.Value + 1, AimCamera)
	            AutoPlay:Clean(function()
	                RunService:UnbindFromRenderStep(BindKey)
	            end)
	        else
	            for Name: string, State: boolean in Restore do
	                local Module = vape.Modules[Name]
	                if Module and Module.Enabled ~= State then
	                    Module:Toggle()
	                end
	            end
	
	            if Sprinted and Soccer.SprintInput.IsSprintButtonToggled() then
	                Soccer.SprintInput.ToggleSprintButton()
	            end
	
	            CancelShot()
	            StopCharacter()
	            table.clear(Restore)
	            table.clear(Requests)
	            table.clear(Oil)
	            table.clear(Hazards)
	            NextRequest, NextShot, OilGeneration = 0, 0, 0
	            Keeper, Playing, Sprinted, Watching = nil, false, nil, nil
	        end
	    end,
	    Tooltip = "Plays the match for you. As the keeper it holds the middle of the goal, passes to whoever calls for it and carries the ball out itself when nobody does. Out of goal it races loose balls, reads where whoever has it is about to pass, shoot or throw and gets in the way instead of chasing them, carries at the goal, stays near its teammates and away from opponents off the ball, calls for it and answers the calls it gets, all while walking around landmines and the other teams oil. Stands still while play is stopped for a kickoff or a goal."
	})
	
	Drive = AutoPlay:CreateToggle({
	    Name = "Drive modules",
	    Default = true,
	    Tooltip = "Switches AutoGoalkeeper, AutoDribble, AutoTackle, AutoPass, ShotRedirect and Anti-AFK on while this runs and puts them back how you had them afterwards. They do the diving, dodging, tackling, pass solving and shot aiming and stop the game pulling a keeper out for standing still, this only decides what to do."
	})
	Sprinting = AutoPlay:CreateToggle({
	    Name = "Sprint",
	    Default = true,
	    Tooltip = "Holds sprint on so you cover ground at full speed."
	})
	Look = AutoPlay:CreateToggle({
	    Name = "Camera",
	    Default = true,
	    Tooltip = "Turns your camera to follow the play, sideways and up and down, onto the ball or onto the goal while you carry it. It leaves the camera alone while play is stopped, so goal replays and kickoffs look normal."
	})
	LookSpeed = AutoPlay:CreateSlider({
	    Name = "Camera speed",
	    Min = 1,
	    Max = 20,
	    Default = 6,
	    Tooltip = "How quickly the camera turns onto what it is following."
	})
	Range = AutoPlay:CreateSlider({
	    Name = "Shoot range",
	    Min = 20,
	    Max = 160,
	    Default = 60,
	    Tooltip = "How far out from the goal it will shoot rather than carry in further. It starts winding the kick up early so the ball leaves at this range, and with an opponent on it, it shoots from as far as 65 studs instead of losing the ball. A shot leaves at 30 degrees at most and lands around 67 studs out, so past that it has to bounce in and the placement stops meaning much."
	})
	Window = AutoPlay:CreateSlider({
	    Name = "Request window",
	    Min = 0.5,
	    Max = 8,
	    Default = 3,
	    Decimal = 10,
	    Suffix = "s",
	    Tooltip = "How long a teammates call for the ball stays worth answering. Only calls inside AutoPass range count, since that is who actually gets the pass."
	})
	Squeeze = AutoPlay:CreateSlider({
	    Name = "Pressure range",
	    Min = 5,
	    Max = 40,
	    Default = 15,
	    Tooltip = "How close an opponent counts as being on you. Anyone inside this makes it move the ball on instead of holding it, and it tries to stay at least this far from opponents when picking where to stand."
	})
	Tether = AutoPlay:CreateSlider({
	    Name = "Teammate range",
	    Min = 10,
	    Max = 80,
	    Default = 30,
	    Tooltip = "How far from its nearest teammate it will drift off the ball, so there is always a short pass on. It still keeps a few studs apart so the two of you are not marked by the same opponent. Your own keeper does not count."
	})
	Avoid = AutoPlay:CreateToggle({
	    Name = "Avoid hazards",
	    Default = true,
	    Tooltip = "Walks around the other teams oil and every landmine on the pitch instead of straight through them, with or without the ball. It still steps onto oil when the ball is sitting in it, never onto a mine."
	})
	MineDistance = AutoPlay:CreateSlider({
	    Name = "Mine distance",
	    Min = 3,
	    Max = 20,
	    Default = 8,
	    Tooltip = "How far to keep from a landmine. The mine itself is tiny, but when it goes off the blast knocks down anyone within 14 studs."
	})
	Safety = AutoPlay:CreateSlider({
	    Name = "Lane safety",
	    Min = 1,
	    Max = 25,
	    Default = 8,
	    Tooltip = "How close an opponent may get to a shot or pass lane before it counts as blocked. Their keeper is left out for shots, since beating the keeper is what ShotRedirect is for."
	})
	Spread = AutoPlay:CreateSlider({
	    Name = "Step size",
	    Min = 4,
	    Max = 40,
	    Default = 16,
	    Tooltip = "How far each repositioning step reaches. Bigger steps commit harder, smaller ones settle more tightly on the best spot."
	})
	Delay = AutoPlay:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0,
	    DefaultMax = 0.1,
	    Decimal = 100
	})
end)

Run(function()
	local AutoPowerup
	local OwnBall
	local AutoJump
	local ChargeLead
	local Horizon
	
	local Charged: boolean?
	
	AutoPowerup = vape.Categories.Utility:CreateModule({
	    Name = "AutoPowerup",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoPowerup:Clean(RunService.PostSimulation:Connect(function()
	                if not Entity.isAlive then
	                    Charged = false
	                    return
	                end
	
	                local _, State = GetBall()
	                if not State or State.Mode == "Resting" or State.Mode == "Rolling" then
	                    Charged = false
	                    return
	                end
	
	                if OwnBall.Enabled and State.LastKickerUserId ~= LocalPlayer.UserId then
	                    return
	                end
	
	                local Step, Position, NeedsJump = GetIntercept(State, Horizon.Value, 25)
	                if not Step then
	                    return
	                end
	
	                local Humanoid: Humanoid = Entity.character.Humanoid
	                local Flat: Vector3 = (Position - Entity.character.RootPart.Position) * Vector3.new(1, 0, 1)
	                if Flat.Magnitude > 1.5 then
	                    MoveCharacter(Flat.Unit)
	                end
	
	                if NeedsJump and AutoJump.Enabled and Humanoid.FloorMaterial ~= Enum.Material.Air and Step <= math.sqrt(2 * Humanoid.JumpHeight / workspace.Gravity) then
	                    Humanoid.Jump = true
	                end
	
	                if Charged or Step > ChargeLead.Value or Soccer.ShootInput.IsCharging() then
	                    return
	                end
	
	                local Input = GetInput("Kick")
	                if not Input then
	                    return
	                end
	
	                Charged = true
	                Soccer.ShootInput.HandleInputBegan(Input, false)
	            end))
	        else
	            if Charged then
	                Soccer.ShootInput.CancelCharge()
	            end
	            Charged = false
	        end
	    end,
	    Tooltip = "Times the jump onto your own flick and winds the kick up for you, leaving the shot for you to take."
	})
	
	OwnBall = AutoPowerup:CreateToggle({
	    Name = "Own ball only",
	    Default = true,
	    Tooltip = "Only times balls you put in the air yourself, not every loose ball."
	})
	AutoJump = AutoPowerup:CreateToggle({
	    Name = "Auto jump",
	    Default = true,
	    Tooltip = "Jumps so you peak exactly as the ball comes down to you."
	})
	ChargeLead = AutoPowerup:CreateSlider({
	    Name = "Charge lead",
	    Min = 0.05,
	    Max = 1.2,
	    Default = 0.4,
	    Decimal = 100,
	    Suffix = "s",
	    Tooltip = "How long before the ball reaches you that the kick starts winding up."
	})
	Horizon = AutoPowerup:CreateSlider({
	    Name = "Horizon",
	    Min = 0.5,
	    Max = 5,
	    Default = 2.5,
	    Decimal = 10,
	    Suffix = "s",
	    Tooltip = "How far ahead the balls flight is read."
	})
end)

Run(function()
	local AutoTeam
	local Side
	local Lock
	
	local FlatMask: Vector3 = Vector3.new(1, 0, 1)
	local Wanted: string?
	local OldQueue: (...any) -> ...any
	local HookQueue: ((...any) -> ...any)?
	
	local function GetJoinPart(Team: string)
	    for _, v: Instance in Soccer.TeamJoinPlatforms.GetTaggedPlatforms(Team) do
	        local Join = Soccer.TeamJoinPlatforms.GetJoinPart(v)
	        if Join then
	            return Join
	        end
	    end
	
	    return nil
	end
	
	local function GetSide(): string
	    if Side.Value ~= "Auto" then
	        return Side.Value == "Red" and "Team1" or "Team2"
	    end
	    if Wanted then
	        return Wanted
	    end
	
	    local Counts: {[string]: number} = {Team1 = 0, Team2 = 0}
	    for _, v: Player in Players:GetPlayers() do
	        local Team: string? = v ~= LocalPlayer and Soccer.ActorTeams.GetActorTeamName(v) or nil
	        if Team and Counts[Team] then
	            Counts[Team] += 1
	        end
	    end
	
	    Wanted = Counts.Team1 <= Counts.Team2 and "Team1" or "Team2"
	
	    return Wanted
	end
	
	AutoTeam = vape.Categories.Utility:CreateModule({
	    Name = "AutoTeam",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not HookQueue then
	                OldQueue = Soccer.RankedState.JoinQueue
	                HookQueue = function(...)
	                    if AutoTeam.Enabled and Lock.Enabled then
	                        vape:CreateNotification("AutoTeam", "Blocked a ranked queue, you would have been teleported off this server", 5, "alert")
	                        return
	                    end
	                    return OldQueue(...)
	                end
	                Soccer.RankedState.JoinQueue = HookQueue
	            end
	
	            AutoTeam:Clean(RunService.PostSimulation:Connect(function()
	                if not Entity.isAlive then
	                    return
	                end
	                if Soccer.Lobby.IsInMatch() then
	                    Wanted = nil
	                    return
	                end
	
	                local Join = GetJoinPart(GetSide())
	                if not Join then
	                    return
	                end
	
	                local Flat: Vector3 = (Join.Position - Entity.character.RootPart.Position) * FlatMask
	                if Flat.Magnitude > 2 then
	                    MoveCharacter(Flat.Unit)
	                else
	                    MoveCharacter(Vector3.zero)
	                end
	            end))
	        else
	            if Soccer.RankedState.JoinQueue == HookQueue then
	                Soccer.RankedState.JoinQueue = OldQueue
	                HookQueue = nil
	            end
	            StopCharacter()
	            Wanted = nil
	        end
	    end,
	    Tooltip = "Walks you onto the team platform in the lobby so you end up on the side you picked. Standing on the pad is the only thing the game accepts, moving your character straight there gets corrected back."
	})
	
	Side = AutoTeam:CreateDropdown({
	    Name = "Side",
	    List = {"Auto", "Red", "Blue"},
	    Tooltip = "Which platform to stand on. Auto takes whichever side has fewer players and holds that choice until the next lobby."
	})
	Lock = AutoTeam:CreateToggle({
	    Name = "Stay on this server",
	    Default = true,
	    Tooltip = "Blocks the ranked queue. Queueing hands you to the matchmaker, which teleports you into a public match on another server."
	})
end)

Run(function()
	local AutoVolley
	local Action
	local FullPower
	local OwnKicks
	local Goalkeeper
	
	local NextPress: number = 0
	
	local function GetHandler()
	    if Action.Value == "Pass" or Action.Value == "Lob" then
	        return Action.Value, Soccer.PassInput
	    end
	    
	    return "Kick", Soccer.ShootInput
	end
	
	AutoVolley = vape.Categories.Utility:CreateModule({
	    Name = "AutoVolley",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoVolley:Clean(RunService.PostSimulation:Connect(function()
	                if not Entity.isAlive or os.clock() < NextPress then
	                    return
	                end
	                if Soccer.ShootInput.IsCharging() or Soccer.PassInput.IsCharging() or Soccer.ItemUseState.AreBallControlsBlocked() then
	                    return
	                end
	                if not Goalkeeper.Enabled and Soccer.GoalkeeperRole.IsGoalkeeper() then
	                    return
	                end
	
	                local State = Soccer.Renderer.GetAuthoritativeMovementState()
	                if not State or not OwnKicks.Enabled and State.LastKickerUserId == LocalPlayer.UserId then
	                    return
	                end
	                if not Soccer.VolleyOpportunity.IsAvailable(Entity.character.Character) then
	                    return
	                end
	
	                local ActionName, Handler = GetHandler()
	                local Input = GetInput(ActionName)
	                if not Input then
	                    return
	                end
	
	                NextPress = os.clock() + 0.1
	                Handler.HandleInputBegan(Input, false)
	                if not Handler.IsVolleyCharging() then
	                    if Handler.IsCharging() then
	                        Handler.CancelCharge()
	                    end
	                    return
	                end
	
	                if not FullPower.Enabled then
	                    Input.UserInputState = Enum.UserInputState.End
	                    Handler.HandleInputEnded(Input)
	                end
	            end))
	        else
	            NextPress = 0
	        end
	    end,
	    Tooltip = "Takes the volley the moment the game offers one, locking a ball that is flying at you onto your foot and striking it out of the air."
	})
	
	Action = AutoVolley:CreateDropdown({
	    Name = "Action",
	    List = {"Shot", "Pass", "Lob"},
	    Tooltip = "Which kick takes the volley. Shot fires it along your aim, Pass and Lob play it the way your own pass and lob keys would."
	})
	FullPower = AutoVolley:CreateToggle({
	    Name = "Full power",
	    Default = true,
	    Tooltip = "Holds the volley until it is fully charged while the ball waits on your foot. Off strikes it the moment it arrives, with less power the closer it was."
	})
	OwnKicks = AutoVolley:CreateToggle({
	    Name = "Own kicks",
	    Tooltip = "Also volleys balls you kicked yourself, off by default so it leaves your own passes and flicks alone."
	})
	Goalkeeper = AutoVolley:CreateToggle({
	    Name = "Goalkeeper",
	    Tooltip = "Also volleys while you are the goalkeeper, off by default so saves stay with you and AutoGoalkeeper."
	})
end)

Run(function()
	local FakeLag
	local Mode
	local Delay
	local Offset
	
	local MaxHeld: number = 100
	local Overdue: number = 0.09
	local Randomizer: Random = Random.new()
	local Queue: {any} = {}
	local MovementRemote
	local Namecall, OldSend, OldRelease
	local HookSend, HookRelease
	local Acted, Dumping, LastSent = 0, 0, 0
	local Sending: boolean = false
	
	local function Push(...)
	    local Packet = table.pack(...)
	    for i: number = 1, Packet.n do
	        local Value = Packet[i]
	        if typeof(Value) == "buffer" then
	            local Copy: buffer = buffer.create(buffer.len(Value))
	            buffer.copy(Copy, 0, Value)
	            Packet[i] = Copy
	        end
	    end
	
	    Packet.Time = os.clock()
	    table.insert(Queue, Packet)
	end
	
	local function Release(Count: number)
	    for _ = 1, Count do
	        local Packet = table.remove(Queue, 1)
	        if not Packet then
	            break
	        end
	
	        Sending = true
	        pcall(MovementRemote.FireServer, MovementRemote, table.unpack(Packet, 1, Packet.n))
	        Sending = false
	    end
	
	    LastSent = os.clock()
	end
	
	local function GetReady(Now: number): number
	    if #Queue >= MaxHeld or not FakeLag.Enabled then
	        return #Queue
	    end
	
	    local DelaySeconds: number = Delay.Value / 1000
	    if Mode.Value == "Repel" then
	        return Now >= Dumping and #Queue or 0
	    end
	    if Mode.Value == "Dynamic" and Acted >= Queue[1].Time then
	        return #Queue
	    end
	
	    local Spacing: number = Mode.Value == "Dynamic" and Offset.Value / 1000 or 0
	    local Ready: number = 0
	    for _, Packet: any in Queue do
	        local Age: number = Now - Packet.Time
	        if Age < DelaySeconds then
	            break
	        end
	        if Spacing > 0 and Age < DelaySeconds + Overdue and Now - LastSent < Spacing then
	            break
	        end
	        Ready += 1
	    end
	
	    return Ready
	end
	
	FakeLag = vape.Categories.Utility:CreateModule({
	    Name = "FakeLag",
	    Function = function(Callback: boolean)
	        if Callback then
	            MovementRemote = Soccer.Remotes.Get("Characters", "MovementUpdate")
	            Acted, Dumping, LastSent = 0, 0, os.clock()
	
	            if not HookSend then
	                OldSend = Soccer.ActionRemoteProtocol.Send
	                HookSend = function(...)
	                    Acted = os.clock()
	                    if FakeLag.Enabled and Mode.Value == "Repel" then
	                        Dumping = Acted + (Delay.Value / 1000) + Randomizer:NextNumber(0, 0.1)
	                    end
	                    return OldSend(...)
	                end
	                Soccer.ActionRemoteProtocol.Send = HookSend
	            end
	
	            if not HookRelease then
	                OldRelease = Soccer.ActionRemoteProtocol.Release
	                HookRelease = function(...)
	                    Acted = os.clock()
	                    return OldRelease(...)
	                end
	                Soccer.ActionRemoteProtocol.Release = HookRelease
	            end
	
	            Namecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	                if self == MovementRemote and not Sending and FakeLag.Enabled and getnamecallmethod() == "FireServer" then
	                    if Mode.Value ~= "Repel" or os.clock() < Dumping then
	                        Push(...)
	                        return
	                    end
	                end
	
	                return Namecall(self, ...)
	            end))
	
	            FakeLag:Clean(RunService.Heartbeat:Connect(function()
	                if #Queue == 0 then
	                    return
	                end
	
	                local Ready: number = GetReady(os.clock())
	                if Ready > 0 then
	                    Release(Ready)
	                end
	            end))
	        elseif OldSend then
	            if Namecall then
	                hookmetamethod(game, "__namecall", Namecall)
	                Namecall = nil
	            end
	            if Soccer.ActionRemoteProtocol.Send == HookSend then
	                Soccer.ActionRemoteProtocol.Send = OldSend
	                HookSend = nil
	            end
	            if Soccer.ActionRemoteProtocol.Release == HookRelease then
	                Soccer.ActionRemoteProtocol.Release = OldRelease
	                HookRelease = nil
	            end
	            if MovementRemote then
	                Release(#Queue)
	            end
	            table.clear(Queue)
	        end
	    end,
	    Tooltip = "Holds your movement packets back so the server, and everyone watching you, sees where you were instead of where you are."
	})
	
	Offset = FakeLag:CreateSlider({
	    Name = "Transmission offset",
	    Min = 0,
	    Max = 50,
	    Default = 5,
	    Darker = true,
	    Tooltip = "Spaces the held packets out as they go, which makes the connection look less steady. Dynamic only."
	})
	Mode = FakeLag:CreateDropdown({
	    Name = "Mode",
	    List = {"Latency", "Dynamic", "Repel"},
	    Tooltip = "Latency holds every packet by the same delay. Dynamic holds them but lets them all go the moment you tackle, kick or pass. Repel only lags while you act, then dumps the lot at once so you snap away from them."
	})
	Delay = FakeLag:CreateSlider({
	    Name = "Delay",
	    Min = 1,
	    Max = 1000,
	    Default = 100,
	    Suffix = "ms",
	    Tooltip = "How long each packet waits before it is sent. This adds straight onto your real ping."
	})
end)

Run(function()
	vape.Categories.Utility:CreateModule({
	    Name = "InfiniteStamina",
	    Function = function(Callback: boolean)
	        Soccer.Sprint.SetUnlimitedStamina(LocalPlayer, "catvape", Callback)
	    end,
	    Tooltip = "Stops sprinting, tackling, diving and kicking from draining your stamina bar."
	})
end)

Run(function()
	local AntiAFK
	
	AntiAFK = vape.Categories.World:CreateModule({
	    Name = "Anti-AFK",
	    Function = function(Callback: boolean)
	        for _, Connection: any in getconnections(LocalPlayer.Idled) do
	            Connection[Callback and "Disable" or "Enable"](Connection)
	        end
	
	        if Callback then
	            AntiAFK:Clean(RunService.Heartbeat:Connect(function()
	                Soccer.MovementActivity.RecordActivity()
	            end))
	        end
	    end,
	    Tooltip = "Stops the game pulling you out of the match. It sends you back to the lobby after 60 seconds without a move command, 120 in goal, so this holds that idle clock at zero as well as blocking the Roblox idle kick."
	})
end)