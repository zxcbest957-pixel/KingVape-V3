local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end

local collectionService = cloneref(game:GetService('CollectionService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local tweenService = cloneref(game:GetService('TweenService'))
local inputService = cloneref(game:GetService('UserInputService'))
local starterPlayerScripts = cloneref(game:GetService('StarterPlayer')).StarterPlayerScripts
local playersService = cloneref(game:GetService('Players'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local playerScripts = lplr.PlayerScripts
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local getvapeasset = vape.Libraries.getvapeasset

local function notif(...)
	return vape:CreateNotification(...)
end

local smear = {}
local function equip(tool, legit)
	if legit then
		entitylib.character.Humanoid:EquipTool(tool)
		return
	end

	tool.Parent = entitylib.character.Character
end

local function getItem(item)
	for _, v in lplr.Backpack:GetChildren() do
		if v:GetAttribute('ItemId') == item then
			return v, false
		end
	end
	if entitylib.isAlive then
		local v = lplr.Character:FindFirstChildOfClass('Tool')
		return (v and v:GetAttribute('ItemId') == item and v or nil), true
	end
	return nil
end
local function switchItem(item, legit)
	if smear.WeaponRegistry[item:GetAttribute('ItemId') or item.Name] and not legit then
		replicatedStorage.Events.CombatEvent:FireServer('ToolEquipped', nil, nil, item:GetAttribute('ItemId') or item.Name, {
			SourceCharacter = lplr.Character
		})
	else
		equip(item, legit)
	end
end

local chargeTimes = {}
local function getCharge(item)
	if not chargeTimes[item] then
		local config = smear.WeaponConfigs.getConfig(item)
		chargeTimes[item] = config and config.ChargeTime or 0
	end

	if chargeTimes[item] <= 0 then
		return 1
	end

	return math.clamp((tick() - smear.ChargeState.GetClock().LastAttackTime) / chargeTimes[item], 0, 1)
end

local ViewmodelTool
local ViewmodelMotor

run(function()
	smear = {
		AnimationService = require(replicatedStorage.Shared.AnimationService),
		Net = require(replicatedStorage.Shared.Net),
		TankBlockEvent = replicatedStorage.Events.TankBlockEvent,
		GridUtil = require(replicatedStorage.Shared.GridUtil),
		ClientBlockBreakVisuals = require(starterPlayerScripts.Client.ClientBlockBreakVisuals),
		OffhandEvent = replicatedStorage.Events.OffhandEvent,
		CombatEvent = replicatedStorage.Events.CombatEvent,
		SpearEvent = replicatedStorage.Events.SpearEvent,
		UseItemEvent = replicatedStorage.Events.UseItemEvent,
		KnockbackEvent = replicatedStorage.Events.KnockbackEvent,
		DownedEvent = replicatedStorage.Events.DownedEvent,
		CombatAirState = require(replicatedStorage.Shared.CombatAirState),
		LiquidRaycast = require(replicatedStorage.Shared.LiquidRaycast),
		ReviveMinigameConfig = require(replicatedStorage.Shared.ReviveMinigameConfig),
		PlayerKeybinds = require(playerScripts.Client.PlayerKeybinds),
		WeaponRegistry = debug.getupvalue(require(replicatedStorage.Shared.WeaponRegistry).create, 2),
		WeaponConfigs = require(replicatedStorage.Shared.WeaponRegistry),
		ChargeState = require(replicatedStorage.Shared.SharedWeaponChargeState)
	}
	smear.BreakingEvent = smear.Net.get('BreakingEvent')

	local reporter, old
	for _, v in getconnections(replicatedStorage.Events.RuntimeDiagnosticsEvent.OnClientEvent) do
		if v.Function and debug.getinfo(v.Function, 's').short_src:find('RuntimeDiagnostics') then
			reporter = debug.getupvalue(v.Function, 1)
			old = hookfunction(reporter, function()
				vape:CreateNotification('Vape', 'Blocked a detection attempt.', 7, 'alert')
			end)
			break
		end
	end

	for _, v in workspace.Mobs:GetChildren() do
		entitylib.addEntity(v)
	end
	vape:Clean(workspace.Mobs.ChildAdded:Connect(entitylib.addEntity))
	vape:Clean(workspace.Mobs.ChildRemoved:Connect(entitylib.removeEntity))
	vape:Clean(function()
		if reporter then
			if restorefunction then
				restorefunction(reporter)
			else
				hookfunction(reporter, old)
			end
		end

		table.clear(smear)
	end)
end)

for _, v in {'SilentAim', 'TriggerBot', 'HighJump'} do
	vape:Remove(v)
end

run(function()
	local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'Criticals',
		Function = function(callback)
			if callback then
				old = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
					if self == smear.CombatEvent and getnamecallmethod() == 'FireServer' then
						local data = select(5, ...)
	
						if type(data) == 'table' then
							data.IsFalling = true
						end
					end
	
					return old(self, ...)
				end))
			elseif old then
				hookmetamethod(game, '__namecall', old)
				old = nil
			end
		end,
		Tooltip = 'Always hit criticals'
	})
end)

run(function()
	local TriggerBot
	local Targets
	local ExtraDelay
	local Distance
	local Size
	local MouseDelay
	local SwitchDelay
	local AutoCharge
	local ShieldBreaker
	local Legit
	local Crit
	
	local lastTarget, mouseDelay
	local inExtra, extraDelay
	local inSwitch, switchDelay
	
	local overlapCheck = OverlapParams.new()
	overlapCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function getEntity()
		local chars = {}
		for _, v in entitylib.List do
			if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) and entitylib.isVulnerable(v) then
				chars[v.Character] = v
			end
		end
	
		overlapCheck.FilterDescendantsInstances = {entitylib.character.Character, gameCamera}
	
		for _, v in workspace:GetPartBoundsInBox(gameCamera.CFrame + gameCamera.CFrame.LookVector * (Distance.Value / 2), Vector3.new(Size.Value, Size.Value, Distance.Value), overlapCheck) do
			local ent = chars[v:FindFirstAncestorOfClass('Model')]
	
			if ent then
				return ent
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat task.wait()
					if not entitylib.isAlive then continue end
	
					local target = getEntity()
					if not target then
						lastTarget = nil
						continue
					end
	
					if lastTarget ~= target then
						lastTarget = target
						mouseDelay = os.clock() + MouseDelay:GetRandomValue()
						inExtra = false
						continue
					end
	
					if not inExtra then
						if os.clock() >= mouseDelay then
							inExtra = true
							extraDelay = os.clock() + ExtraDelay:GetRandomValue()
						end
						continue
					end
	
					local tool = entitylib.character.Character:FindFirstChildOfClass('Tool')
					if not tool then
						lastTarget = nil
						continue
					end
	
					if AutoCharge.Enabled and getCharge(tool:GetAttribute('ItemId') or tool.Name) < 1 then continue end
	
					local offhand = ShieldBreaker.Enabled and target.Character:FindFirstChild('OffhandVisual')
	
					if offhand and offhand:GetAttribute('ItemId') == 'Shield' then
						if not inSwitch then
							inSwitch = true
							switchDelay = os.clock() + SwitchDelay:GetRandomValue()
						end
	
						if os.clock() >= switchDelay then
							local axe, equipped = getItem('Axe')
	
							if axe then
								if not equipped then
									switchItem(axe, Legit.Enabled)
								end
	
								local held = axe.Parent == entitylib.character.Character and axe or tool
								held:Activate()
	
								if tool ~= axe then
									switchItem(tool, Legit.Enabled)
								end
							end
	
							inSwitch = false
						end
						continue
					end
	
					if Crit.Enabled and not smear.CombatAirState.get(entitylib.character.Character).IsDescending then continue end
					if os.clock() < extraDelay then continue end
	
					tool:Activate()
					lastTarget = nil
				until not TriggerBot.Enabled
			else
				lastTarget = nil
				inExtra, inSwitch = false, false
			end
		end,
		Tooltip = 'Attacks whoever you aim at.'
	})
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ExtraDelay = TriggerBot:CreateTwoSlider({
		Name = 'Extra Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.125,
		Decimal = 100
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 32,
		Default = 16
	})
	Size = TriggerBot:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 6
	})
	MouseDelay = TriggerBot:CreateTwoSlider({
		Name = 'Mouse Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0.025,
		DefaultMax = 0.05,
		Decimal = 100
	})
	SwitchDelay = TriggerBot:CreateTwoSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0.025,
		DefaultMax = 0.075,
		Decimal = 100
	})
	AutoCharge = TriggerBot:CreateToggle({
		Name = 'Auto Charge'
	})
	ShieldBreaker = TriggerBot:CreateToggle({
		Name = 'Shield Breaker'
	})
	Legit = TriggerBot:CreateToggle({
		Name = 'Legit Equip'
	})
	Crit = TriggerBot:CreateToggle({
		Name = 'Crits Only'
	})
end)

run(function()
	local LumberTycoon
	local Mode
	local Range
	
	local gridSize = smear.GridUtil.getGridSize()
	local gridBox = Vector3.new(gridSize * 0.5, gridSize * 0.5, gridSize * 0.5)
	local scanHeight = 30000
	
	local overlapCheck = OverlapParams.new()
	overlapCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function getBlockId(pos)
		for _, v in workspace:GetPartBoundsInBox(CFrame.new(pos), gridBox) do
			local id = v:GetAttribute('OriginalId') or v:GetAttribute('BlockId')
			if type(id) == 'string' then
				return id
			end
		end
	end
	
	local function breakBlock(v)
		if not v:IsA('BasePart') then return end
	
		if type(v:GetAttribute('TankBlockId')) == 'string' and type(v:GetAttribute('TankAssemblyId')) == 'string' then
			smear.ClientBlockBreakVisuals.beginDynamic(v)
			smear.ClientBlockBreakVisuals.addDynamicProgress(v, 9e9)
			smear.TankBlockEvent:FireServer('Mine', v, 9e9)
		elseif v:GetAttribute('BlockId') or v:GetAttribute('OriginalId') or v:GetAttribute('Breakable') then
			local pos = smear.GridUtil.snapToGrid(v.Position)
	
			if getBlockId(pos) then
				smear.ClientBlockBreakVisuals.begin(pos)
				smear.ClientBlockBreakVisuals.addProgress(pos, 9e9)
				smear.BreakingEvent:FireServer(pos, 9e9)
			end
		end
	end
	
	LumberTycoon = vape.Categories.Blatant:CreateModule({
		Name = '👺',
		Function = function(callback)
			if callback then
				repeat task.wait(0.05)
					if entitylib.isAlive then
						if Mode.Value == 'Normal' then
							for _, v in workspace:GetPartBoundsInRadius(entitylib.character.RootPart.Position, Range.Value) do
								breakBlock(v)
							end
						else
							local center = entitylib.character.RootPart.Position - Vector3.new(0, scanHeight * 0.5, 0)
							local size = Vector3.new(Range.Value, scanHeight, Range.Value)
							overlapCheck.FilterDescendantsInstances = {entitylib.character.Character}
	
							for _, v in workspace:GetPartBoundsInBox(CFrame.new(center), size, overlapCheck) do
								breakBlock(v)
							end
						end
					end
	
					smear.ClientBlockBreakVisuals.clear()
					smear.ClientBlockBreakVisuals.clearDynamic()
				until not LumberTycoon.Enabled
			end
		end,
		Tooltip = 'Instantly breaks every block around you.'
	})
	Mode = LumberTycoon:CreateDropdown({
		Name = 'Mode',
		List = {'Normal', 'Stabshot'}
	})
	Range = LumberTycoon:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 100,
		Default = 20
	})
end)

run(function()
	local Fly
	local Speed
	local VerticalSpeed
	
	local up, down = 0, 0
	local chargeTime = 0
	local launched = false
	local freeze, freezeTime
	local oldFriction = {}
	
	local tpHeight = 10
	local hoverSpeed = 2.25
	local chargeDelay = 0.5
	local equipDelay = 0.05
	local launchTimeout = 0.5
	local bounceLength = 40
	local bounceDelay = 0.4
	local groundDirection = Vector3.new(0, -7, 0)
	
	local groundCheck = RaycastParams.new()
	groundCheck.RespectCanCollide = true
	
	local function applyFriction()
		for _, v in entitylib.character.Character:GetChildren() do
			if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldFriction[v] then
				oldFriction[v] = v.CustomPhysicalProperties or 'none'
				v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
			end
		end
	end
	
	local function launch()
		local charge, equipped = getItem('WindCharge')
		if not charge then return end
	
		local old = entitylib.character.Character:FindFirstChildOfClass('Tool')
		if not equipped then
			switchItem(charge)
			task.wait(equipDelay)
	
			if not entitylib.isAlive then return end
		end
	
		launched = false
		freeze, freezeTime = entitylib.character.RootPart.Position, os.clock() + launchTimeout
		smear.UseItemEvent:FireServer('WindCharge', (entitylib.character.Head or entitylib.character.RootPart).Position, Vector3.new(0, -1, 0), charge:GetAttribute('SelectedInventoryStackKey'))
	
		repeat task.wait() until launched or not freeze or not Fly.Enabled or not entitylib.isAlive
		freeze = nil
	
		if not entitylib.isAlive then return end
	
		if launched then
			entitylib.character.RootPart.CFrame += Vector3.new(0, tpHeight, 0)
		end
	
		if old and old ~= charge and old.Parent then
			switchItem(old)
		end
	end
	
	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if callback then
				up = inputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0
				down = inputService:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 0
	
				if entitylib.isAlive then
					applyFriction()
				end
	
				Fly:Clean(entitylib.Events.LocalAdded:Connect(applyFriction))
	
				Fly:Clean(smear.KnockbackEvent.OnClientEvent:Connect(function()
					launched = true
					freeze = nil
				end))
	
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then return end
	
					local root = entitylib.character.RootPart
	
					if freeze then
						if os.clock() < freezeTime then
							root.CFrame = CFrame.lookAlong(freeze, root.CFrame.LookVector)
							root.AssemblyLinearVelocity = Vector3.zero
							return
						end
	
						freeze = nil
					end
	
					groundCheck.FilterDescendantsInstances = {entitylib.character.Character, gameCamera}
					groundCheck.CollisionGroup = root.CollisionGroup
	
					local bounce = ((tick() % bounceDelay) / bounceDelay > 0.5 and 1 or -1) * bounceLength
					local move = entitylib.character.Humanoid.MoveDirection * Speed.Value * dt
					local ray = workspace:Raycast(root.Position, move, groundCheck)
	
					root.CFrame += ray and ((ray.Position + ray.Normal) - root.Position) or move
					root.AssemblyLinearVelocity = Vector3.new(0, hoverSpeed + ((up + down) * VerticalSpeed.Value) + bounce, 0)
	
					if os.clock() < chargeTime then return end
	
					if not workspace:Raycast(root.Position, groundDirection, groundCheck) then return end
	
					chargeTime = os.clock() + chargeDelay
					task.spawn(launch)
				end))
	
				for _, v in {'InputBegan', 'InputEnded'} do
					Fly:Clean(inputService[v]:Connect(function(input)
						if inputService:GetFocusedTextBox() then return end
	
						if input.KeyCode == Enum.KeyCode.Space then
							up = v == 'InputBegan' and 1 or 0
						elseif input.KeyCode == Enum.KeyCode.LeftShift then
							down = v == 'InputBegan' and -1 or 0
						end
					end))
				end
			else
				for i, v in oldFriction do
					i.CustomPhysicalProperties = v ~= 'none' and v or nil
				end
	
				table.clear(oldFriction)
				up, down = 0, 0
				chargeTime = 0
				freeze = nil
				launched = false
			end
		end,
		Tooltip = 'Makes you go zoom, space & leftshift to go up and down.'
	})
	Speed = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalSpeed = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local HighJump
	local Height
	local Speed
	
	local launched, climbing = false, false
	local startY = 0
	local freeze, freezeTime
	
	local equipDelay = 0.05
	local launchTimeout = 2
	
	local function launch()
		local charge, equipped = getItem('WindCharge')
		if not charge then
			notif('HighJump', 'No windcharge found', 8, 'warning')
			return
		end
	
		local old = entitylib.character.Character:FindFirstChildOfClass('Tool')
		if not equipped then
			switchItem(charge, true)
			task.wait(equipDelay)
	
			if not entitylib.isAlive then return end
		end
	
		launched = false
		freeze, freezeTime = entitylib.character.RootPart.Position, os.clock() + launchTimeout
		smear.UseItemEvent:FireServer('WindCharge', entitylib.character.RootPart.Position, Vector3.new(0, -1, 0), charge:GetAttribute('SelectedInventoryStackKey'))
	
		repeat task.wait() until launched or not freeze or not HighJump.Enabled or not entitylib.isAlive
		freeze = nil
	
		if not entitylib.isAlive then return end
	
		if old and old ~= charge and old.Parent then
			switchItem(old, true)
		end
	
		return launched
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
		Name = 'HighJump',
		Function = function(callback)
			if callback then
				if not entitylib.isAlive then
					HighJump:Toggle()
					return
				end
	
				startY = entitylib.character.RootPart.Position.Y
				climbing = false
	
				HighJump:Clean(smear.KnockbackEvent.OnClientEvent:Connect(function()
					launched, climbing = true, true
					freeze = nil
				end))
	
				HighJump:Clean(runService.PreSimulation:Connect(function()
					if not entitylib.isAlive then return end
	
					local root = entitylib.character.RootPart
	
					if freeze then
						if os.clock() < freezeTime then
							root.CFrame = CFrame.lookAlong(freeze, root.CFrame.LookVector)
							root.AssemblyLinearVelocity = Vector3.zero
							return
						end
	
						freeze = nil
					end
	
					if not climbing then return end
	
					if root.Position.Y - startY >= Height.Value then
						HighJump:Toggle()
						return
					end
	
					root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Speed.Value, root.AssemblyLinearVelocity.Z)
				end))
	
				task.spawn(function()
					if not launch() and HighJump.Enabled then
						HighJump:Toggle()
					end
				end)
			else
				freeze = nil
				launched, climbing = false, false
			end
		end,
		Tooltip = 'Rides a wind charge straight up.'
	})
	Height = HighJump:CreateSlider({
		Name = 'Height',
		Min = 10,
		Max = 150,
		Default = 50,
		Suffix = 'studs'
	})
	Speed = HighJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local Max
	local Speed
	local Mouse
	local Legit
	local AutoCharge
	local ShieldBreaker
	local BoxColor
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	
	local anims, armC0, animTween = vape.Libraries.auraanims
	local attacking = false
	local Boxes = {}
	local AttackDelay = setmetatable({}, {__mode = 'k'})
	
	
	local function getWeapon()
		local tool = entitylib.character.Character:FindFirstChildOfClass('Tool')
		if tool and smear.WeaponRegistry[tool:GetAttribute('ItemId') or tool.Name] then
			return tool
		end
	
		for _, v in lplr.Backpack:GetChildren() do
			if smear.WeaponRegistry[v:GetAttribute('ItemId') or v.Name] then
				return v
			end
		end
	end
	
	local function getHitbox(char)
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') and (collectionService:HasTag(v, 'CombatHitbox') or collectionService:HasTag(v, 'PlayerHitbox')) then
				return v
			end
		end
		return char:FindFirstChild('HumanoidRootPart')
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if Animation.Enabled then
					task.spawn(function()
						local started = false
	
						repeat
							local motor = ViewmodelMotor
	
							if motor then
								if attacking and not started then
									local first = not started
	
									if first then
										armC0 = motor.C0
									end
	
									started = true
	
									if AnimationMode.Value == 'Random' then
										anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
									end
	
									for _, v in anims[AnimationMode.Value] do
										animTween = tweenService:Create(motor, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
											C0 = armC0 * v.CFrame
										})
										animTween:Play()
										animTween.Completed:Wait()
										first = false
	
										if not Killaura.Enabled or not attacking then break end
									end
								elseif started then
									started = false
									animTween = tweenService:Create(motor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
										C0 = armC0
									})
									animTween:Play()
								end
							end
	
							if not started then
								task.wait(1 / 60)
							end
						until not Killaura.Enabled or not Animation.Enabled
					end)
				end
	
				repeat task.wait(0.016)
					local attacked = {}
	
					if entitylib.isAlive and not (Mouse.Enabled and not inputService:IsMouseButtonPressed(0)) then
						local tool = getWeapon()
	
						if tool then
							local localPosition = entitylib.character.RootPart.Position
							local facing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local charge = getCharge(tool:GetAttribute('ItemId') or tool.Name)
							local state = smear.CombatAirState.get(entitylib.character.Character)
							local item = tool:GetAttribute('ItemId') or tool.Name
	
							for _, v in entitylib.AllPosition({
								Range = AttackRange.Value,
								Wallcheck = Targets.Walls.Enabled or nil,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Priority = Targets.Priority.Value,
								Limit = Max.Value
							}) do
								local delta = (v.RootPart.Position - localPosition) * Vector3.new(1, 0, 1)
								if delta.Magnitude > 0 and math.acos(math.clamp(facing.Unit:Dot(delta.Unit), -1, 1)) > (math.rad(AngleSlider.Value) / 2) then continue end
	
								table.insert(attacked, v)
								targetinfo.Targets[v] = tick() + 1
	
								local hitbox = getHitbox(v.Character)
								if not hitbox then continue end
	
								local weapon, weaponItem, weaponCharge = tool, item, charge
	
								local offhand = ShieldBreaker.Enabled and v.Character:FindFirstChild('OffhandVisual')
	
								if offhand and offhand:GetAttribute('ItemId') == 'Shield' then
									local axe = getItem('Axe')
	
									if axe then
										weapon = axe
										weaponItem = axe:GetAttribute('ItemId') or axe.Name
										weaponCharge = getCharge(weaponItem)
									end
								end
	
								if (AutoCharge.Enabled and weaponCharge < 1) or not AutoCharge.Enabled and os.clock() - (AttackDelay[v.Character] or 0) < (1 / Speed.Value) then continue end
								AttackDelay[v.Character] = os.clock()
	
								if weapon.Parent ~= entitylib.character.Character and (Legit.Enabled or weapon ~= tool) then
									switchItem(weapon, true)
								end
	
								if AutoCharge.Enabled then
									smear.ChargeState.GetClock().LastAttackTime = tick()
								end
	
								smear.CombatEvent:FireServer(v.Humanoid, hitbox, weaponCharge, weaponItem, {
									SourceCharacter = entitylib.character.Character,
									IsFalling = state.IsDescending
								})
	
								if weapon ~= tool then
									switchItem(tool, true)
								end
							end
	
							if Face.Enabled and attacked[1] then
								local root = entitylib.character.RootPart
								local pos = attacked[1].RootPart.Position
								root.CFrame = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y + 0.01, pos.Z))
							end
						end
					end
	
					if vape.ThreadFix then
						setthreadidentity(8)
					end
					attacking = attacked[1] ~= nil
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].RootPart or nil
						v.Color3 = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
						v.Transparency = 1 - BoxColor.Opacity
					end
				until not Killaura.Enabled
			else
				attacking = false
	
				local motor = armC0 and ViewmodelMotor
	
				if motor then
					animTween = tweenService:Create(motor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					animTween:Play()
				end
	
				for _, v in Boxes do
					v.Adornee = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 32,
		Default = 16,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	Speed = Killaura:CreateSlider({
		Name = 'Attack speed',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = 'cps'
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Legit = Killaura:CreateToggle({Name = 'Legit Switch'})
	ShieldBreaker = Killaura:CreateToggle({
		Name = 'Shield Breaker',
		Tooltip = 'Swap to your axe for targets that are blocking.'
	})
	AutoCharge = Killaura:CreateToggle({
		Name = 'Auto Charge',
		Tooltip = 'Wait for a full charge before swinging so every hit deals full damage.'
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			AnimationTween.Object.Visible = callback
	
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			if BoxColor then
				BoxColor.Object.Visible = callback
			end
	
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	local animnames = {'Normal'}
	for i in anims do
		if i ~= 'Normal' then
			table.insert(animnames, i)
		end
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Value
	local AutoDisable
	local old
	
	local JumpTick, JumpSpeed = tick(), 0
	local FreezeTick, JumpTimeout = 0, 2
	local methods = {
	    WindCharge = function()
	        if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
	            local item, equipped = getItem('WindCharge')
	            if not item then
	                notif('LongJump', 'No windcharge found', 8, 'warning')
	                return false
	            end
	            if not equipped then
	                switchItem(item, true)
	            end
	            smear.UseItemEvent:FireServer('WindCharge', entitylib.character.RootPart.Position, Vector3.new(0, -1, 0), item:GetAttribute('SelectedInventoryStackKey'))
	
	            local launched = false
	            local connection = replicatedStorage.Events.KnockbackEvent.OnClientEvent:Connect(function()
	                launched = true
	            end)
	
	            local timeout = tick() + JumpTimeout
	            repeat task.wait() until launched or tick() >= timeout or not LongJump.Enabled or not entitylib.isAlive
	            connection:Disconnect()
	
	            if not launched then return false end
	
	            entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
	            JumpTick, JumpSpeed = tick() + 3, Value.Value
	            return true
	        end
	        return false
	    end
	}
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
	            old = lplr.Character:FindFirstChildOfClass('Tool')
	            local start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
	            FreezeTick = tick() + JumpTimeout
	            task.spawn(function()
	                local suc = false
	                for _, v in methods do
	                    if v() then
	                        suc = true
	
	                        if old then
	                            switchItem(old, true)
	                        end
	                        break
	                    end
	                end
	                if not suc then
	                    notif('LongJump', 'Couldn\'t find a compatible item to longjump', 8, 'info')
	                    LongJump:Toggle()
	                end
	            end)
	            local Direction = entitylib.character.RootPart.CFrame.LookVector
	            LongJump:Clean(runService.PreSimulation:Connect(function(dt)
	                local root = entitylib.isAlive and entitylib.character.RootPart or nil
	
	                if root then
	                    if JumpTick > tick() then
	                        local destination = (Direction * math.max(((JumpTick - tick()) > 1.1 and JumpSpeed or 0), 0) * dt) * Vector3.new(1, 0, 1)
	                        local velo = tick() > (JumpTick - 1.1) and -25 or 15
	                        root.CFrame += destination
	                        root.AssemblyLinearVelocity = (Direction * (tick() > JumpTick and 32 or JumpSpeed)) + Vector3.new(0, velo, 0)
	                        start = nil
	                    else
	                        if start then
	                            if tick() < FreezeTick then
	                                root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
	                                root.AssemblyLinearVelocity = Vector3.zero
	                            else
	                                start = nil
	                            end
	                        end
	                        JumpSpeed = 0
	                    end
	                else
	                    start = nil
	                end
	            end))
	        else
	            JumpTick, JumpSpeed = tick(), 0
	            FreezeTick = 0
	            if old then
	                if entitylib.isAlive then
	                    switchItem(old, true)
	                end
	                old = nil
	            end
			end
		end,
		ExtraText = function()
			return 'wemmbu bypaass'
		end,
		Tooltip = 'Lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Jump Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = LongJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)

run(function()
	local NoFall
	
	local rayParams = RaycastParams.new()
	
	NoFall = vape.Categories.Blatant:CreateModule({ 
	    Name = 'NoFall',
	    Function = function(callback)
	        if callback then
	            local tracked, extraGravity = 0, 0
	            NoFall:Clean(runService.PreSimulation:Connect(function(dt)
	                if entitylib.isAlive then
	                    local root = entitylib.character.RootPart
	                    if root.AssemblyLinearVelocity.Y < -40 then
	                        rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
	                        rayParams.CollisionGroup = root.CollisionGroup
	
	                        local rootSize = root.Size.Y / 2.5 + entitylib.character.HipHeight
	                        local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
	                        if not ray then
	                            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -41, root.AssemblyLinearVelocity.Z)
	                            root.CFrame = root.CFrame + Vector3.new(0, extraGravity * dt, 0)
	                            extraGravity = extraGravity + -workspace.Gravity * dt
	                        end
	                    else
	                        extraGravity = 0
	                    end
	                end
	            end))
	        end
	    end,
	    Tooltip = 'Prevents you from taking fall damage.'
	})
	
end)

run(function()
	local AutoMace
	local Targets
	local Distance
	local Spoof
	local FallDistance
	local OnlyFall
	local Aim
	local Delay
	local Max
	
	local maceRange = 16
	local minFallDistance = 6
	local landedWindow = 0.25
	local attackInterval = 0.25
	local smashAnimation = 'rbxassetid://90330371628268'
	
	local attempt = 0
	local ready = false
	local lastAttack = 0
	local startY, fallDistance = 0, 0
	local lastFall, lastFallSpeed, lastFallTime = 0, 0, -math.huge
	local inDelay, delayTime = false, 0
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function setReady(state)
		if ready == state then return end
	
		ready = state
		smear.CombatEvent:FireServer('SetMaceSmashReady', state, nil, 'Mace', {
			SourceCharacter = entitylib.character.Character
		})
	end
	
	local function sampleMiss(cf, data)
		local ignore = {entitylib.character.Character}
		for _, v in {'Effects', 'Pickups'} do
			local folder = workspace:FindFirstChild(v)
	
			if folder then
				table.insert(ignore, folder)
			end
		end
	
		local direction = cf.LookVector * maceRange
		data.SmashMissRayOrigin = cf.Position
		data.SmashMissTipPosition = cf.Position + direction
	
		for _ = 1, 8 do
			rayCheck.FilterDescendantsInstances = ignore
	
			local ray = workspace:Raycast(cf.Position, direction, rayCheck)
			if not ray then return end
	
			local model = ray.Instance:FindFirstAncestorOfClass('Model')
			if not collectionService:HasTag(ray.Instance, 'CombatHitbox') and not collectionService:HasTag(ray.Instance, 'PlayerHitbox') and not smear.LiquidRaycast.isLiquidPart(ray.Instance) and not (model and model:FindFirstChildWhichIsA('Humanoid')) and (ray.Instance:GetAttribute('BlockId') or ray.Instance:GetAttribute('OriginalId') or ray.Instance:GetAttribute('Breakable')) then
				data.SmashMissImpactPosition = ray.Position
				data.SmashMissImpactIsBlock = true
				return
			end
	
			table.insert(ignore, model or ray.Instance)
		end
	end
	
	local function getHitbox(char)
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') and (collectionService:HasTag(v, 'CombatHitbox') or collectionService:HasTag(v, 'PlayerHitbox')) then
				return v
			end
		end
		return char:FindFirstChild('HumanoidRootPart')
	end
	
	AutoMace = vape.Categories.Utility:CreateModule({
		Name = 'AutoMace',
		Function = function(callback)
			if callback then
				repeat task.wait()
					if not entitylib.isAlive then continue end
	
					local mace = entitylib.character.Character:FindFirstChildWhichIsA('Tool')
					if not mace or mace.Name ~= 'Mace' or lplr:GetAttribute('IsBlocking') then
						setReady(false)
						continue
					end
	
					local state = smear.CombatAirState.get(entitylib.character.Character)
					local position = entitylib.character.RootPart.Position
	
					if state.IsAirborne then
						startY = math.max(startY, position.Y)
						fallDistance = math.max(startY - position.Y, 0)
					else
						startY = position.Y
						fallDistance = 0
					end
	
					local smashing = not OnlyFall.Enabled or (state.IsDescending and fallDistance > minFallDistance)
					if smashing then
						lastFall = fallDistance
						lastFallSpeed = state.FallSpeed
						lastFallTime = os.clock()
					end
	
					setReady(smashing)
	
					if not smashing and not (lastFall > minFallDistance and os.clock() - lastFallTime <= landedWindow) then
						inDelay = false
						continue
					end
	
					if os.clock() - lastAttack < attackInterval then
						inDelay = false
						continue
					end
	
					local ents = entitylib.AllPosition({
						Range = math.clamp(Distance.Value, 0, 32),
						Wallcheck = Targets.Walls.Enabled or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Limit = Max.Value
					})
	
					if #ents == 0 then
						inDelay = false
						continue
					end
	
					if not inDelay then
						inDelay = true
						delayTime = os.clock() + Delay:GetRandomValue()
						continue
					end
	
					if os.clock() < delayTime then continue end
					inDelay = false
	
					local aim = CFrame.new((entitylib.character.Head or entitylib.character.RootPart).Position, ents[1].RootPart.Position)
					if Aim.Enabled then
						gameCamera.CFrame = CFrame.new(gameCamera.CFrame.Position, ents[1].RootPart.Position)
					end
	
					attempt += 1
					lastAttack = os.clock()
	
					local data = {
						SourceCharacter = entitylib.character.Character,
						SmashAttemptId = attempt,
						AimDirection = aim.LookVector,
						FallDistance = Spoof.Enabled and FallDistance.Value or (smashing and fallDistance or lastFall),
						FallSpeed = Spoof.Enabled and math.sqrt(2 * workspace.Gravity * FallDistance.Value) or (smashing and state.FallSpeed or lastFallSpeed)
					}
	
					sampleMiss(aim, data)
	
					local charge = mace:FindFirstChild('ChargeValue') and mace.ChargeValue.Value or 1
					smear.CombatEvent:FireServer('BeginMaceSmash', nil, charge, 'Mace', data)
	
					for _, v in ents do
						local hitbox = getHitbox(v.Character)
						if not hitbox then continue end
	
						local hitData = table.clone(data)
						hitData.ClientMaceSmashHurtbox = true
						hitData.ClientMaceSmashHitPosition = hitbox.Position
	
						smear.CombatEvent:FireServer(v.Humanoid, hitbox, charge, 'Mace', hitData)
	
						if Spoof.Enabled then
							entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(0, 2.5, 0)
						end
					end
	
					smear.AnimationService.play(entitylib.character.Humanoid, smashAnimation, Enum.AnimationPriority.Action, 0.1, 1, 1)
	
					lastFall, lastFallSpeed, lastFallTime = 0, 0, -math.huge
					setReady(false)
				until not AutoMace.Enabled
			else
				if entitylib.isAlive then
					setReady(false)
				end
	
				ready = false
				lastAttack = 0
				startY, fallDistance = 0, 0
				lastFall, lastFallSpeed, lastFallTime = 0, 0, -math.huge
				inDelay, delayTime = false, 0
			end
		end,
		Tooltip = 'Smashes nearby players with your mace.'
	})
	Targets = AutoMace:CreateTargets({
		Players = true,
		Walls = true,
		NPCs = true
	})
	Distance = AutoMace:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 32,
		Default = 20
	})
	Spoof = AutoMace:CreateToggle({
		Name = 'Spoof fall distance',
		Function = function(callback)
			if FallDistance and FallDistance.Object then
				FallDistance.Object.Visible = callback
			end
		end
	})
	FallDistance = AutoMace:CreateSlider({
		Name = 'Fall distance',
		Min = 1,
		Max = 200,
		Default = 100,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Darker = true,	
		Visible = false
	})
	OnlyFall = AutoMace:CreateToggle({
		Name = 'Only falling',
		Default = true
	})
	Aim = AutoMace:CreateToggle({
		Name = 'Look At Target'
	})
	Delay = AutoMace:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0,
		DefaultMax = 0.05,
		Decimal = 100
	})
	Max = AutoMace:CreateSlider({
		Name = 'Max Targets',
		Min = 1,
		Max = 10,
		Default = 1
	})
end)

run(function()
	local AutoRevive
	local AutoStart
	local Delay
	local Inaccuracy
	
	local startTimeout = 3.5
	
	local handler
	local difficulty
	local offsets = {}
	local pending, pendingTime = false, 0
	local attemptStart, nextBar = 0, 1
	local inDelay, startDelay = false, 0
	
	local function press()
		if not handler then
			for _, v in getconnections(smear.PlayerKeybinds.ActionBegan) do
				if v.Function and debug.getinfo(v.Function, 's').short_src:find('ReviveMinigame') then
					handler = v.Function
					break
				end
			end
		end
	
		if handler then
			handler('StartRevive')
		else
			firesignal(smear.PlayerKeybinds.ActionBegan, 'StartRevive')
		end
	end
	
	local function clearAttempt()
		difficulty = nil
		pending, pendingTime = false, 0
		attemptStart, nextBar = 0, 1
		inDelay, startDelay = false, 0
		table.clear(offsets)
	end
	
	local function beginAttempt(data)
		pending = false
	
		if typeof(data) ~= 'table' or typeof(data.Difficulty) ~= 'table' or typeof(data.Difficulty.FailureCount) ~= 'number' then return end
	
		local attempt = smear.ReviveMinigameConfig.getDifficulty(data.Difficulty.FailureCount, data.Difficulty.Variant == 'Pact' and 'Pact' or 'Base')
		if attempt.BarCount <= 0 then return end
	
		difficulty = attempt
		attemptStart, nextBar = os.clock(), 1
	
		local limit = smear.ReviveMinigameConfig.getWindows(attempt.Variant).Amazing * 0.4
	
		table.clear(offsets)
		for i = 1, attempt.BarCount do
			offsets[i] = (math.random() < 0.5 and -1 or 1) * math.min(Inaccuracy:GetRandomValue(), limit)
		end
	end
	
	AutoRevive = vape.Categories.Utility:CreateModule({
		Name = 'AutoRevive',
		Function = function(callback)
			if callback then
				AutoRevive:Clean(smear.DownedEvent.OnClientEvent:Connect(function(action, data)
					if action == 'ReviveStarted' then
						beginAttempt(data)
					elseif action == 'ReviveStartRejected' or action == 'ReviveCancelled' or action == 'ReviveOutcome' then
						clearAttempt()
					end
				end))
	
				repeat local step = task.wait()
					if not lplr:GetAttribute('IsDowned') then
						if difficulty or pending or inDelay then
							clearAttempt()
						end
						continue
					end
	
					if difficulty then
						if not lplr:GetAttribute('InReviveMinigame') then
							clearAttempt()
							continue
						end
	
						local beat = attemptStart + difficulty.LeadTime + ((nextBar - 1) * difficulty.BarGap)
						local now = os.clock() + (step * 0.5)
	
						if now < beat + offsets[nextBar] then continue end
	
						if now - beat <= difficulty.GoodWindow then
							press()
						end
	
						nextBar += 1
						if nextBar > difficulty.BarCount then
							difficulty = nil
						end
						continue
					end
	
					if not AutoStart.Enabled or lplr:GetAttribute('InReviveMinigame') then
						inDelay = false
						continue
					end
	
					if pending then
						if os.clock() - pendingTime < startTimeout then continue end
						pending = false
					end
	
					if not inDelay then
						inDelay = true
						startDelay = os.clock() + Delay:GetRandomValue()
						continue
					end
	
					if os.clock() < startDelay then continue end
	
					inDelay = false
					pending, pendingTime = true, os.clock()
					press()
				until not AutoRevive.Enabled
			else
				clearAttempt()
				handler = nil
			end
		end,
		Tooltip = 'Plays the downed revive minigame for you, hitting every beat as it crosses the marker.'
	})
	AutoStart = AutoRevive:CreateToggle({
		Name = 'Auto start',
		Default = true,
		Function = function(callback)
			if Delay and Delay.Object then
				Delay.Object.Visible = callback
			end
		end
	})
	Delay = AutoRevive:CreateTwoSlider({
		Name = 'Start delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0.2,
		DefaultMax = 0.4,
		Decimal = 100,
		Darker = true
	})
	Inaccuracy = AutoRevive:CreateTwoSlider({
		Name = 'Inaccuracy',
		Min = 0,
		Max = 0.02,
		DefaultMin = 0,
		DefaultMax = 0.01,
		Decimal = 1000
	})
	
end)

run(function()
	local PickupRange
	local Range
	local UseWhitelist
	local Whitelist
	local Enchantments
	
	local function isAllowed(item)
		if not UseWhitelist.Enabled then return true end
		if not table.find(Whitelist.ListEnabled, (item:GetAttribute('ItemId') or item.Name:gsub('Pickup_', '')):lower()) then return false end
		if table.find(Enchantments.ListEnabled, 'all') or not smear.WeaponRegistry[item:GetAttribute('ItemId')] then return true end
	
		for _, v in (item:GetAttribute('Enchantments') or ''):split(',') do
			if table.find(Enchantments.ListEnabled, v) then
				return true
			end
		end
		return false
	end
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				repeat task.wait(0.1)
					if not entitylib.isAlive then continue end
	
					for _, v in workspace.Pickups:GetChildren() do
						local interest = v:FindFirstChild('TouchInterest', true)
	
						if interest and lplr:DistanceFromCharacter(interest.Parent.Position) <= Range.Value and isAllowed(v) then
							firetouchinterest(interest.Parent, entitylib.character.RootPart, 0)
							firetouchinterest(interest.Parent, entitylib.character.RootPart, 1)
						end
					end
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up items from further away.'
	})
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	UseWhitelist = PickupRange:CreateToggle({
		Name = 'Use whitelist',
		Default = true,
		Function = function(callback)
			if Whitelist then
				Whitelist.Object.Visible = callback
				Enchantments.Object.Visible = callback
			end
		end
	})
	Whitelist = PickupRange:CreateTextList({
		Name = 'Whitelist',
		Default = {'totemofundying'},
		Darker = true
	})
	Enchantments = PickupRange:CreateTextList({
		Name = 'Enchantments',
		Default = {'windburst'},
		Darker = true
	})
end)

run(function()
	local FastBreak
	local Value
	
	local fireServer = smear.BreakingEvent.FireServer
	local old
	
	FastBreak = vape.Categories.World:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				old = hookfunction(fireServer, function(self, pos, progress, ...)
					if self == smear.BreakingEvent and not vape.Modules['👺'].Enabled then
						return old(self, pos, Value.Value, ...)
					end
	
					return old(self, pos, progress, ...)
				end)
			elseif old then
				hookfunction(fireServer, old)
				old = nil
			end
		end,
		Tooltip = 'Break blocks faster when mining.'
	})
	Value = FastBreak:CreateSlider({
		Name = 'Harvest Spees',
		Min = 14,
		Max = 30,
		Default = 14,
		Decimal = 10
	})
end)

run(function()
	local AutoTotem
	local Delay
	local ExtraDelay
	local TotemCount
	
	local label
	local offhandSlot
	local totemDelay
	local inDelay = false
	
	local function countTotems()
		local total = 0
		for _, v in lplr.Backpack:GetChildren() do
			if v:GetAttribute('ItemId') == 'TotemOfUndying' then
				total += 1
			end
		end
		return total
	end
	
	AutoTotem = vape.Categories.Inventory:CreateModule({
		Name = 'AutoTotem',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat task.wait()
					if not (offhandSlot and offhandSlot.Parent) then
						offhandSlot = lplr.PlayerGui:FindFirstChild('OffhandSlot', true)
					end
	
					if not entitylib.isAlive or not offhandSlot then continue end
	
					if label and TotemCount.Enabled then
						label.Text = tostring(countTotems())
					end
	
					if offhandSlot:GetAttribute('ItemId') then continue end
	
					local totem = getItem('TotemOfUndying')
					if not totem then continue end
	
					if not inDelay then
						inDelay = true
						totemDelay = os.clock() + Delay:GetRandomValue() + (math.random() < 0.18 and math.random() * ExtraDelay:GetRandomValue() or 0)
					end
	
					if os.clock() >= totemDelay then
						smear.OffhandEvent:FireServer('Set', totem.Name, totem)
						inDelay = false
					end
				until not AutoTotem.Enabled
			else
				inDelay = false
			end
		end,
		Tooltip = 'Moves a totem into your offhand whenever it empties.'
	})
	Delay = AutoTotem:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		DefaultMin = 0.22,
		DefaultMax = 0.34,
		Decimal = 100
	})
	ExtraDelay = AutoTotem:CreateTwoSlider({
		Name = 'ExtraDelay',
		Min = 0,
		Max = 1,
		DefaultMin = 0.22,
		DefaultMax = 0.34,
		Decimal = 100
	})
	TotemCount = AutoTotem:CreateToggle({
		Name = 'TotemCount',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Name = 'TotemCount'
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.Arial
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.RichText = true
				label.Size = UDim2.fromOffset(100, 20)
				label.Text = '0'
				label.TextColor3 = Color3.fromRGB(0, 255, 0)
				label.TextSize = 18
				label.Visible = AutoTotem.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)

run(function()
	local SpearLunge
	local Mode
	local ChargeDelay
	local Legit
	local EquipDelay
	
	local minHorizontal = 0.08
	
	local function lunge()
		if not entitylib.isAlive then return end
	
		local spear, equipped = getItem('Spear')
		if not spear then
			notif('SpearLunge', 'No Spear found in your hotbar.', 5, 'alert')
			return
		end
	
		local cooldown = lplr:GetAttribute('SpearBoostCooldownEnd')
		if cooldown and tick() < cooldown then return end
	
		local direction = gameCamera.CFrame.LookVector
		if Mode.Value == 'Boost' and Vector3.new(direction.X, 0, direction.Z).Magnitude < minHorizontal then return end
	
		local old = entitylib.character.Character:FindFirstChildOfClass('Tool')
		if not equipped then
			switchItem(spear, Legit.Enabled)
	
			if Legit.Enabled then
				task.wait(EquipDelay.Value)
			end
		end
	
		if Mode.Value == 'LookBoost' then
			smear.SpearEvent:FireServer('StartCharge')
			task.wait(ChargeDelay.Value)
		end
	
		smear.SpearEvent:FireServer(Mode.Value, direction)
	
		if old and old ~= spear then
			if Legit.Enabled then
				task.wait(EquipDelay.Value)
			end
	
			switchItem(old, Legit.Enabled)
		end
	end
	
	SpearLunge = vape.Categories.Inventory:CreateModule({
		Name = 'SpearLunge',
		Function = function(callback)
			if callback then
				lunge()
				SpearLunge:Toggle()
			end
		end,
		Tooltip = 'Swaps to your spear, lunges and swaps back to your old item.'
	})
	Mode = SpearLunge:CreateDropdown({
		Name = 'Method',
		List = {'LookBoost', 'Boost'}
	})
	ChargeDelay = SpearLunge:CreateSlider({
		Name = 'Charge Delay',
		Min = 0,
		Max = 0.5,
		Default = 0.05,
		Decimal = 100
	})
	Legit = SpearLunge:CreateToggle({
		Name = 'Legit Equip',
		Function = function(callback)
			if EquipDelay then
				EquipDelay.Object.Visible = callback
			end
		end
	})
	EquipDelay = SpearLunge:CreateSlider({
		Name = 'Equip Delay',
		Min = 0,
		Max = 0.5,
		Default = 0.05,
		Decimal = 100,
		Visible = false
	})
end)

run(function()
	local Viewmodel
	local Hands
	local Horizontal
	local Vertical
	local Depth
	local oldtool
	
	local function setArms(hidden)
		if not entitylib.isAlive then return end
	
		for _, v in {'Right Arm', 'Left Arm'} do
			local part = entitylib.character.Character:FindFirstChild(v)
	
			if part then
				part.LocalTransparencyModifier = hidden and 1 or 0
				part.Transparency = hidden and 1 or 0
			end
		end
	end
	
	local function newTool(obj)
		if not obj:IsA('Tool') or not obj:FindFirstChild('Handle') then return end
	
		oldtool = obj
		ViewmodelTool = oldtool.Handle:Clone()
		ViewmodelTool.CanCollide = false
		ViewmodelTool.CanQuery = false
		ViewmodelTool.Massless = true
		ViewmodelTool.Anchored = true
	
		for _, v in ViewmodelTool:GetDescendants() do
			if v:IsA('BaseScript') or v:IsA('Sound') then
				v:Destroy()
			end
		end
	
		ViewmodelTool.Parent = gameCamera
		ViewmodelTool.LocalTransparencyModifier = 0
		oldtool.Handle.LocalTransparencyModifier = 1
	end
	
	local function newCharacter(char)
		Viewmodel:Clean(char.Character.ChildAdded:Connect(newTool))
		Viewmodel:Clean(char.Character.ChildRemoved:Connect(function(obj)
			if obj == oldtool then
				ViewmodelTool:Destroy()
				ViewmodelTool = nil
				oldtool = nil
			end
		end))
	
		local tool = char.Character:FindFirstChildOfClass('Tool')
		if tool then
			newTool(tool)
		end
	end
	
	Viewmodel = vape.Legit:CreateModule({
		Name = 'Viewmodel',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_viewmodel.png'),
		Function = function(callback)
			if callback then
				ViewmodelMotor = Instance.new('Motor6D')
				vape:Clean(ViewmodelMotor)
				vape:Clean(runService.RenderStepped:Connect(function()
					local swing = gameCamera:FindFirstChild('LocalFirstPersonWeaponSwing')
	
					if swing then
						for _, v in swing:GetDescendants() do
							if v:IsA('BasePart') and (Hands.Enabled or v:FindFirstAncestorWhichIsA('Tool')) then
								v.LocalTransparencyModifier = 1
								v.Transparency = 1
							end
						end
					end
	
					if oldtool and oldtool.Parent then
						oldtool.Handle.LocalTransparencyModifier = 1
					end
	
					if Hands.Enabled then
						setArms(true)
					end
	
					if ViewmodelTool then
						local dcf = ((CFrame.new(2.06, -2.44, -2.24) * CFrame.new(0.6 + Horizontal.Value, -0.2 + Vertical.Value, -0.6 - Depth.Value)) * CFrame.Angles(math.rad(99), math.rad(2), math.rad(-4))) * ViewmodelMotor.C0
						local offsetcf = (CFrame.new(0, -0.15, -1.56) * CFrame.Angles(math.rad(-90), math.rad(-90), math.rad(-50)))
						ViewmodelTool.CFrame = ((gameCamera.CFrame * dcf) * offsetcf)
					end
				end))
				vape:Clean(entitylib.Events.LocalAdded:Connect(newCharacter))
	
				if entitylib.isAlive then
					newCharacter(entitylib.character)
				end
			else
				setArms(false)
	
				if ViewmodelTool then
					ViewmodelTool:Destroy()
					ViewmodelTool = nil
				end
	
				if oldtool and oldtool.Parent then
					oldtool.Handle.LocalTransparencyModifier = 0
				end
	
				oldtool = nil
			end
		end,
		Tooltip = 'Replaces the default viewmodel'
	})
	Hands = Viewmodel:CreateToggle({
		Name = 'Hide hands',
		Default = true,
		Function = function(callback)
			if not callback and Viewmodel.Enabled then
				setArms(false)
			end
		end
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = -4,
		Max = 4,
		Default = 0,
		Decimal = 100
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -4,
		Max = 4,
		Default = 0,
		Decimal = 100
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = -4,
		Max = 4,
		Default = 0,
		Decimal = 100
	})
end)