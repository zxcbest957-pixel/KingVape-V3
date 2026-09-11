local loadstring = function(...)
	local str = ...
	if typeof(str) ~= 'string' or str == '' then
		return function() end
	end
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('KingVape', 'Failed to load : '..err, 30, 'alert')
	end
	return res or function() end
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	local content
	if isfile(path) then
		pcall(function() content = readfile(path) end)
	end
	if not content or content == '' or content == '404: Not Found' or typeof(content) ~= 'string' then
		local commit = (isfile('kingvape/profiles/commit.txt') and readfile('kingvape/profiles/commit.txt')) or 'main'
		commit = (commit or 'main'):gsub('%s+', '')
		if commit == '' then commit = 'main' end
		local relPath = select(1, path:gsub('kingvape/', ''))
		local url = 'https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/'..commit..'/'..relPath
		local cdnUrl = 'https://cdn.jsdelivr.net/gh/zxcbest957-pixel/KingVape-V3@'..commit..'/'..relPath

		local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
		if httpRequest then
			pcall(function()
				local res = httpRequest({Url = url, Method = 'GET'})
				if res and res.StatusCode == 200 and typeof(res.Body) == 'string' and res.Body ~= '' then
					content = res.Body
				else
					local cdnRes = httpRequest({Url = cdnUrl, Method = 'GET'})
					if cdnRes and cdnRes.StatusCode == 200 and typeof(cdnRes.Body) == 'string' and cdnRes.Body ~= '' then
						content = cdnRes.Body
					end
				end
			end)
		end

		if not content or typeof(content) ~= 'string' or content == '' then
			pcall(function()
				local res = game:HttpGet(url, true)
				if typeof(res) == 'string' and res ~= '' and res ~= '404: Not Found' then
					content = res
				else
					local cdnRes = game:HttpGet(cdnUrl, true)
					if typeof(cdnRes) == 'string' and cdnRes ~= '' and cdnRes ~= '404: Not Found' then
						content = cdnRes
					end
				end
			end)
		end

		if content and typeof(content) == 'string' and content ~= '404: Not Found' and content ~= '' then
			if path:find('%.lua') then
				content = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..content
			end
			pcall(writefile, path, content)
		end
	end
	if typeof(content) ~= 'string' then content = '' end
	return (func or readfile)(path)
end
local buildclock = os.clock()
local run = function(func)
	func()

	if os.clock() - buildclock > 0.004 then
		task.wait()
		buildclock = os.clock()
	end
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local proxService = cloneref(game:GetService('ProximityPromptService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local stats = cloneref(game:GetService('Stats'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontbounds = vape.Libraries.getfontbounds
local getvapeasset = vape.Libraries.getvapeasset
local uipallet = vape.Libraries.uipallet

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getvapeasset('kingvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function rakNetCheck(module)
	if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
		notif(module, 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		return false
	end

	return true
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('kingvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('kingvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('kingvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	tagcallback = {},
	data = {WhitelistedUsers = {}},
	hashes = {},
	hooked = false,
	loaded = true,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for i in SpeedMethods do
	if not table.find(SpeedMethodList, i) then
		table.insert(SpeedMethodList, i)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Settings.Modules.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		return 0, true
	end

	function whitelist:isingame()
		return false
	end

	function whitelist:tag(plr, text, rich)
		return ''
	end

	function whitelist:getplayer(arg, plr)
		return false
	end

	function whitelist:playeradded(v, joined)
	end

	function whitelist:process(msg, plr)
		return false
	end

	function whitelist:newchat(obj, plr, skip)
	end

	function whitelist:oldchat(func)
	end

	function whitelist:hook()
	end

	function whitelist:announce(text)
	end

	function whitelist:update(first)
		whitelist.loaded = true
		return true
	end

	whitelist.commands = {}

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)
entitylib.start()

run(function()
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
	local moveConst = Vector2.new(1, 0.77) * math.rad(0.5)
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback
			end
	
			if callback then
				local ent
				local rightClicked = not RightClick.Enabled or inputService:IsMouseButtonPressed(1)
				AimAssist:Clean(runService.RenderStepped:Connect(function(dt)
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end
	
					if rightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
						ent = entitylib.EntityMouse({
							Range = FOV.Value,
							Part = Part.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Wallcheck = Targets.Walls.Enabled,
							Origin = gameCamera.CFrame.Position
						})
	
						if ent then
							local facing = gameCamera.CFrame.LookVector
							local new = (ent[Part.Value].Position - gameCamera.CFrame.Position).Unit
							new = new == new and new or Vector3.zero
	
							if ShowTarget.Enabled then
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if new ~= Vector3.zero then
								local diffYaw = (math.atan2(facing.X, facing.Z) - math.atan2(new.X, new.Z)) % math.pi
								diffYaw -= diffYaw >= (math.pi / 2) and math.pi or 0
								diffYaw += diffYaw < -(math.pi / 2) and math.pi or 0
								local diffPitch = math.asin(facing.Y) - math.asin(new.Y)
								local angle = Vector2.new(diffYaw, diffPitch) // (moveConst * UserSettings():GetService('UserGameSettings').MouseSensitivity)
								angle *= math.min(Speed.Value * dt, 1)
								mousemoverel(angle.X, angle.Y)
							end
						end
					end
				end))
	
				if RightClick.Enabled then
					AimAssist:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							ent = nil
							rightClicked = true
						end
					end))
	
					AimAssist:Clean(inputService.InputEnded:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							rightClicked = false
						end
					end))
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target'
	})
	
	Targets = AimAssist:CreateTargets({Players = true})
	Part = AimAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = AimAssist:CreateSlider({
		Name = 'FOV',
		Min = 0,
		Max = 1000,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Default = 100
	})
	Speed = AimAssist:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 30,
		Default = 15
	})
	AimAssist:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
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
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = AimAssist:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Default = 0.5,
		Visible = false
	})
	CircleFilled = AimAssist:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	RightClick = AimAssist:CreateToggle({
		Name = 'Require right click',
		Function = function()
			if AimAssist.Enabled then
				AimAssist:Toggle()
				AimAssist:Toggle()
			end
		end
	})
	ShowTarget = AimAssist:CreateToggle({
		Name = 'Show target info'
	})
end)

run(function()
	local AutoClicker
	local Mode
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				repeat
					if Mode.Value == 'Tool' then
						local tool = getTool()
						if tool and inputService:IsMouseButtonPressed(0) then
							tool:Activate()
						end
					else
						if mouse1click and (isrbxactive or iswindowactive)() then
							if not vape.gui.ScaledGui.ClickGui.Visible then
								(Mode.Value == 'Click' and mouse1click or mouse2click)()
							end
						end
					end
	
					task.wait(1 / CPS.GetRandomValue())
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Automatically clicks for you'
	})
	
	Mode = AutoClicker:CreateDropdown({
		Name = 'Mode',
		List = {'Tool', 'Click', 'RightClick'},
		Tooltip = 'Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 12
	})
end)

run(function()
	local MurderMystery
	local murderer, sheriff, oldtargetable, oldgetcolor
	
	local function itemAdded(v, plr)
		if v:IsA('Tool') then
			local check = v:FindFirstChild('IsGun') and 'sheriff' or v:FindFirstChild('KnifeServer') and 'murderer' or nil
			check = check or v.Name:lower():find('knife') and 'murderer' or v.Name:lower():find('gun') and 'sheriff' or nil
	
			if check == 'murderer' and plr ~= murderer then
				murderer = plr
				if plr.Character then
					entitylib.refresh()
				end
			elseif check == 'sheriff' and plr ~= sheriff then
				sheriff = plr
				if plr.Character then
					entitylib.refresh()
				end
			end
		end
	end
	
	local function playerAdded(plr)
		MurderMystery:Clean(plr.DescendantAdded:Connect(function(v)
			itemAdded(v, plr)
		end))
	
		local pack = plr:FindFirstChildWhichIsA('Backpack')
		if pack then
			for _, v in pack:GetChildren() do
				itemAdded(v, plr)
			end
		end
	
		if plr.Character then
			for _, v in plr.Character:GetChildren() do
				itemAdded(v, plr)
			end
		end
	end
	
	MurderMystery = vape.Categories.Combat:CreateModule({
		Name = 'MurderMystery',
		Function = function(callback)
			if callback then
				oldtargetable, oldgetcolor = entitylib.targetCheck, entitylib.getEntityColor
	
				entitylib.getEntityColor = function(ent)
					ent = ent.Player
					if not (ent and vape.Settings.Modules.Options['Use team color'].Enabled) then return end
					if isFriend(ent, true) then
						return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
					end
					return murderer == ent and Color3.new(1, 0.3, 0.3) or sheriff == ent and Color3.new(0, 0.5, 1) or nil
				end
	
				entitylib.targetCheck = function(ent)
					if ent.Player and isFriend(ent.Player) then return false end
					if murderer == lplr then return true end
					return murderer == ent.Player or sheriff == ent.Player
				end
	
				for _, v in playersService:GetPlayers() do
					playerAdded(v)
				end
	
				MurderMystery:Clean(playersService.PlayerAdded:Connect(playerAdded))
				entitylib.refresh()
			else
				entitylib.getEntityColor = oldgetcolor
				entitylib.targetCheck = oldtargetable
				entitylib.refresh()
			end
		end,
		Tooltip = 'Automatic murder mystery teaming based on equipped roblox tools.'
	})
end)

local mouseClicked
run(function()
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
	local RaycastWhitelist = RaycastParams.new()
	RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
	local ProjectileRaycast = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local fireoffset, rand, delayCheck = CFrame.identity, Random.new(), tick()
	local oldnamecall, oldray

	local function getTarget(origin, obj)
		if rand.NextNumber(rand, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then return end
		local targetPart = (rand.NextNumber(rand, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and 'Head' or 'RootPart'
		local ent = entitylib['Entity'..Mode.Value]({
			Range = Range.Value,
			Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
			Part = targetPart,
			Origin = origin,
			Players = Target.Players.Enabled,
			NPCs = Target.NPCs.Enabled
		})

		if ent then
			targetinfo.Targets[ent] = tick() + 1
			if Projectile.Enabled then
				ProjectileRaycast.FilterDescendantsInstances = {gameCamera, ent.Character}
				ProjectileRaycast.CollisionGroup = ent[targetPart].CollisionGroup
			end
		end

		return ent, ent and ent[targetPart], origin
	end

	local Hooks = {
		FindPartOnRayWithIgnoreList = function(args)
			local ent, targetPart, origin = getTarget(args[1].Origin, {args[2]})
			if not ent then return end
			if Wallbang.Enabled then
				return {targetPart, targetPart.Position, targetPart.GetClosestPointOnSurface(targetPart, origin), targetPart.Material}
			end
			args[1] = Ray.new(origin, CFrame.lookAt(origin, targetPart.Position).LookVector * args[1].Direction.Magnitude)
		end,
		Raycast = function(args)
			if MethodRay.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then return end
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			if Wallbang.Enabled then
				RaycastWhitelist.FilterDescendantsInstances = {targetPart}
				args[3] = RaycastWhitelist
			end
		end,
		ScreenPointToRay = function(args)
			local ent, targetPart, origin = getTarget(gameCamera.CFrame.Position)
			if not ent then return end
			local direction = CFrame.lookAt(origin, targetPart.Position)
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				direction = CFrame.lookAt(origin, calc)
			end
			return {Ray.new(origin + (args[3] and direction.LookVector * args[3] or Vector3.zero), direction.LookVector)}
		end,
		Ray = function(args)
			local ent, targetPart, origin = getTarget(args[1])
			if not ent then return end
			if Projectile.Enabled then
				local calc = prediction.SolveTrajectory(origin, ProjectileSpeed.Value, ProjectileGravity.Value, targetPart.Position, targetPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, nil, ProjectileRaycast)
				if not calc then return end
				args[2] = CFrame.lookAt(origin, calc).LookVector * args[2].Magnitude
			else
				args[2] = CFrame.lookAt(origin, targetPart.Position).LookVector * args[2].Magnitude
			end
		end
	}
	Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
	Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
	Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if CircleObject then
				CircleObject.Visible = callback and Mode.Value == 'Mouse'
			end
			if callback then
				if Method.Value == 'Ray' then
					oldray = hookfunction(Ray.new, function(origin, direction)
						if checkcaller() then
							return oldray(origin, direction)
						end
						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldray(origin, direction)
							end
						end

						local args = {origin, direction}
						Hooks.Ray(args)
						return oldray(unpack(args))
					end)
				else
					oldnamecall = hookmetamethod(game, '__namecall', function(...)
						if getnamecallmethod() ~= Method.Value then
							return oldnamecall(...)
						end
						if checkcaller() then
							return oldnamecall(...)
						end

						local calling = getcallingscript()
						if calling then
							local list = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {'ControlScript', 'ControlModule'}
							if table.find(list, tostring(calling)) then
								return oldnamecall(...)
							end
						end

						local self, args = ..., {select(2, ...)}
						local res = Hooks[Method.Value](args)
						if res then
							return unpack(res)
						end
						if setnamecallmethod then
							setnamecallmethod(Method.Value)
						end
						return oldnamecall(self, unpack(args))
					end)
				end

				repeat
					if CircleObject then
						CircleObject.Position = inputService:GetMouseLocation()
					end

					if AutoFire.Enabled then
						local origin = AutoFireMode.Value == 'Camera' and gameCamera.CFrame or entitylib.isAlive and entitylib.character.RootPart.CFrame or CFrame.identity
						local ent = entitylib['Entity'..Mode.Value]({
							Range = Range.Value,
							Wallcheck = Target.Walls.Enabled or nil,
							Part = 'Head',
							Origin = (origin * fireoffset).Position,
							Players = Target.Players.Enabled,
							NPCs = Target.NPCs.Enabled
						})

						if mouse1click and (isrbxactive or iswindowactive)() then
							if ent and canClick() then
								if delayCheck < tick() then
									if mouseClicked then
										mouse1release()
										delayCheck = tick() + AutoFireShootDelay.Value
									else
										mouse1press()
									end
									mouseClicked = not mouseClicked
								end
							else
								if mouseClicked then
									mouse1release()
								end
								mouseClicked = false
							end
						end
					end

					task.wait()
				until not SilentAim.Enabled
			else
				if oldnamecall then
					hookmetamethod(game, '__namecall', oldnamecall)
				end
				if oldray then
					hookfunction(Ray.new, oldray)
				end
				oldnamecall, oldray = nil, nil
			end
		end,
		ExtraText = function()
			return Method.Value:gsub('FindPartOnRay', '')
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})

	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Function = function(val)
			if CircleObject then
				CircleObject.Visible = SilentAim.Enabled and val == 'Mouse'
			end
		end,
		Tooltip = 'Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character'
	})
	Method = SilentAim:CreateDropdown({
		Name = 'Method',
		List = {'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'},
		Function = function(val)
			if SilentAim.Enabled then
				SilentAim:Toggle()
				SilentAim:Toggle()
			end
			MethodRay.Object.Visible = val == 'Raycast'
		end,
		Tooltip = 'FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new'
	})
	MethodRay = SilentAim:CreateDropdown({
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Darker = true,
		Visible = false
	})
	IgnoredScripts = SilentAim:CreateTextList({Name = 'Ignored Scripts'})
	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Function = function(val)
			if CircleObject then
				CircleObject.Radius = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Default = 150
	})
	HitChance = SilentAim:CreateSlider({
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 85,
		Suffix = '%'
	})
	HeadshotChance = SilentAim:CreateSlider({
		Name = 'Headshot Chance',
		Min = 0,
		Max = 100,
		Default = 65,
		Suffix = '%'
	})
	AutoFire = SilentAim:CreateToggle({
		Name = 'AutoFire',
		Function = function(callback)
			AutoFireShootDelay.Object.Visible = callback
			AutoFireMode.Object.Visible = callback
			AutoFirePosition.Object.Visible = callback
		end
	})
	AutoFireShootDelay = SilentAim:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Visible = false,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	AutoFireMode = SilentAim:CreateDropdown({
		Name = 'Origin',
		List = {'RootPart', 'Camera'},
		Visible = false,
		Darker = true,
		Tooltip = 'Determines the position to check for before shooting'
	})
	AutoFirePosition = SilentAim:CreateTextBox({
		Name = 'Offset',
		Function = function()
			local suc, res = pcall(function()
				return CFrame.new(unpack(AutoFirePosition.Value:split(',')))
			end)
			if suc then fireoffset = res end
		end,
		Default = '0, 0, 0',
		Visible = false,
		Darker = true
	})
	Wallbang = SilentAim:CreateToggle({Name = 'Wallbang'})
	SilentAim:CreateToggle({
		Name = 'Range Circle',
		Function = function(callback)
			if callback then
				CircleObject = Drawing.new('Circle')
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = vape.gui.AbsoluteSize / 2
				CircleObject.Radius = Range.Value
				CircleObject.NumSides = 100
				CircleObject.Transparency = 1 - CircleTransparency.Value
				CircleObject.Visible = SilentAim.Enabled and Mode.Value == 'Mouse'
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
			end
			CircleColor.Object.Visible = callback
			CircleTransparency.Object.Visible = callback
			CircleFilled.Object.Visible = callback
		end
	})
	CircleColor = SilentAim:CreateColorSlider({
		Name = 'Circle Color',
		Function = function(hue, sat, val)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = SilentAim:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if CircleObject then
				CircleObject.Transparency = 1 - val
			end
		end,
		Darker = true,
		Default = 0.5,
		Visible = false
	})
	CircleFilled = SilentAim:CreateToggle({
		Name = 'Circle Filled',
		Function = function(callback)
			if CircleObject then
				CircleObject.Filled = callback
			end
		end,
		Darker = true,
		Visible = false
	})
	Projectile = SilentAim:CreateToggle({
		Name = 'Projectile',
		Function = function(callback)
			ProjectileSpeed.Object.Visible = callback
			ProjectileGravity.Object.Visible = callback
		end
	})
	ProjectileSpeed = SilentAim:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	ProjectileGravity = SilentAim:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192.6,
		Default = 192.6,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local rayCheck, delayCheck = RaycastParams.new(), tick()
	
	local function getTriggerBotTarget()
		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	
		local ray = workspace:Raycast(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Distance.Value, rayCheck)
		if ray and ray.Instance then
			for _, v in entitylib.List do
				if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
					if ray.Instance:IsDescendantOf(v.Character) then
						return entitylib.isVulnerable(v) and v
					end
				end
			end
		end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					if mouse1click and (isrbxactive or iswindowactive)() then
						if getTriggerBotTarget() and canClick() then
							if delayCheck < tick() then
								if mouseClicked then
									mouse1release()
									delayCheck = tick() + ShootDelay.Value
								else
									mouse1press()
								end
								mouseClicked = not mouseClicked
							end
						else
							if mouseClicked then
								mouse1release()
							end
							mouseClicked = false
						end
					end
	
					task.wait()
				until not TriggerBot.Enabled
			else
				if mouse1click and (isrbxactive or iswindowactive)() then
					if mouseClicked then
						mouse1release()
					end
				end
				mouseClicked = false
			end
		end,
		Tooltip = 'Shoots people that enter your crosshair'
	})
	
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
		Name = 'Next Shot Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'The delay set after shooting a target'
	})
	Distance = TriggerBot:CreateSlider({
		Name = 'Distance',
		Min = 0,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local part
	
	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				if Method.Value == 'Part' then
					local debounce = os.clock()
					part = Instance.new('Part')
					part.Size = Vector3.new(10000, 1, 10000)
					part.Transparency = 1 - Color.Opacity
					part.Material = Enum.Material[Material.Value]
					part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					part.CanCollide = Mode.Value == 'Collide'
					part.Anchored = true
					part.CanQuery = false
					part.Parent = workspace
	
					AntiFall:Clean(part)
					AntiFall:Clean(part.Touched:Connect(function(touchedpart)
						if touchedpart.Parent == lplr.Character and entitylib.isAlive and debounce < os.clock() then
							local root = entitylib.character.RootPart
							debounce = os.clock() + 0.1
	
							if Mode.Value == 'Velocity' then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
							elseif Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, (100 - root.AssemblyLinearVelocity.Y), 0) * root.AssemblyMass)
							end
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character, part}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
							if ray then
								part.Position = ray.Position - Vector3.new(0, 15, 0)
							end
						end
	
						task.wait(0.1)
					until not AntiFall.Enabled
				else
					local lastpos
					AntiFall:Clean(runService.PreSimulation:Connect(function()
						if entitylib.isAlive then
							local root = entitylib.character.RootPart
							lastpos = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and root.Position or lastpos
							if (root.Position.Y + (root.AssemblyLinearVelocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10) then
								lastpos = lastpos or Vector3.new(root.Position.X, (workspace.FallenPartsDestroyHeight + 20), root.Position.Z)
								root.CFrame += (lastpos - root.Position)
								root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
							end
						end
					end))
				end
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	
	Method = AntiFall:CreateDropdown({
		Name = 'Method',
		List = {'Part', 'Classic'},
		Function = function(val)
			if Mode.Object then
				Mode.Object.Visible = val == 'Part'
				Material.Object.Visible = val == 'Part'
				Color.Object.Visible = val == 'Part'
			end
			if AntiFall.Enabled then
				AntiFall:Toggle()
				AntiFall:Toggle()
			end
		end,
		Tooltip = 'Part - Moves a part under you that does various methods to stop you from falling\nClassic - Teleports you out of the void after reaching the part destroy plane'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Impulse', 'Velocity', 'Collide'},
		Darker = true,
		Function = function(val)
			if part then
				part.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Darker = true,
		Function = function(val)
			if part then
				part.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(h, s, v, o)
			if part then
				part.Color = Color3.fromHSV(h, s, v)
				part.Transparency = 1 - o
			end
		end
	})
end)

local Fly
local LongJump
run(function()
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
	local w, s, a, d, up, down = 0, 0, 0, 0, 0, 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	Options.rayCheck = rayCheck

	local Functions
	Functions = {
		Velocity = function()
			entitylib.character.RootPart.AssemblyLinearVelocity = (entitylib.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0)
		end,
		Impulse = function(options, moveDirection)
			local root = entitylib.character.RootPart
			local diff = (Vector3.new(0, 2.25 + ((up + down) * VerticalValue.Value), 0) - root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
			if diff.Magnitude > 2 then
				root:ApplyImpulse(diff * root.AssemblyMass)
			end
		end,
		CFrame = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if WallCheck.Enabled then
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = root.CollisionGroup
				local ray = workspace:Raycast(root.Position, Vector3.new(0, YLevel - root.Position.Y, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			end
			root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
			root.CFrame += Vector3.new(0, YLevel - root.Position.Y, 0)
		end,
		Bounce = function()
			Functions.AssemblyLinearVelocity()
			entitylib.character.RootPart.AssemblyLinearVelocity += Vector3.new(0, ((tick() % BounceDelay.Value) / BounceDelay.Value > 0.5 and 1 or -1) * BounceLength.Value, 0)
		end,
		Floor = function()
			Platform.CFrame = down ~= 0 and CFrame.identity or entitylib.character.RootPart.CFrame + Vector3.new(0, -(entitylib.character.HipHeight + 0.5), 0)
		end,
		TP = function(dt)
			Functions.CFrame(dt)
			if tick() % (FloatTPAir.Value + FloatTPGround.Value) > FloatTPAir.Value then
				OldYLevel = OldYLevel or YLevel
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
				rayCheck.CollisionGroup = entitylib.character.RootPart.CollisionGroup
				local ray = workspace:Raycast(entitylib.character.RootPart.Position, Vector3.new(0, -1000, 0), rayCheck)
				if ray then
					YLevel = ray.Position.Y + entitylib.character.HipHeight
				end
			else
				if OldYLevel then
					YLevel = OldYLevel
					OldYLevel = nil
				end
			end
		end,
		Jump = function(dt)
			local root = entitylib.character.RootPart
			if not YLevel then
				YLevel = root.Position.Y
			end
			YLevel = YLevel + ((up + down) * VerticalValue.Value * dt)
			if root.Position.Y < YLevel then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	}

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if Platform then
				Platform.Parent = callback and gameCamera or nil
			end

			frictionTable.Fly = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if PlatformStanding.Enabled then
							entitylib.character.Humanoid.PlatformStand = true
							entitylib.character.RootPart.RotVelocity = Vector3.zero
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(entitylib.character.RootPart.CFrame.Position, gameCamera.CFrame.LookVector)
						end

						if State.Value ~= 'None' then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
						end

						SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection, dt)
						Functions[FloatMode.Value](dt)
					else
						YLevel = nil
						OldYLevel = nil
					end
				end))

				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				up, down = 0, 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Fly:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							local divided = Keys.Value:split('/')
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[1]] then
								up = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode[divided[2]] then
								down = v == 'InputBegan' and -1 or 0
							end
						end
					end))
				end

				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				YLevel, OldYLevel = nil, nil
				if entitylib.isAlive then
					if PlatformStanding.Enabled then
						entitylib.character.Humanoid.PlatformStand = false
					end

					if Options.WalkSpeed then
						entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
					end
				end

				Options.WalkSpeed = nil
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Makes you go zoom.'
	})

	Mode = Fly:CreateDropdown({
		Name = 'Speed Mode',
		List = SpeedMethodList,
		Function = function(val)
			WallCheck.Object.Visible = FloatMode.Value == 'CFrame' or FloatMode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	FloatMode = Fly:CreateDropdown({
		Name = 'Float Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Bounce', 'Floor', 'Jump', 'TP'},
		Function = function(val)
			WallCheck.Object.Visible = Mode.Value == 'CFrame' or Mode.Value == 'TP' or val == 'CFrame' or val == 'TP'
			BounceLength.Object.Visible = val == 'Bounce'
			BounceDelay.Object.Visible = val == 'Bounce'
			VerticalValue.Object.Visible = val ~= 'Floor'
			FloatTPGround.Object.Visible = val == 'TP'
			FloatTPAir.Object.Visible = val == 'TP'

			if Platform then
				Platform:Destroy()
				Platform = nil
			end

			if val == 'Floor' then
				Platform = Instance.new('Part')
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.one
				Platform.Transparency = 1
				Platform.Parent = Fly.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Teleports you to the ground within intervals\nFloor - Spawns a part under you\nJump - Presses space after going below a certain Y Level\nBounce - Vertical bouncing motion'
	})
	local states = {'None'}
	for _, v in Enum.HumanoidStateType:GetEnumItems() do
		if v.Name ~= 'Dead' and v.Name ~= 'None' then
			table.insert(states, v.Name)
		end
	end
	State = Fly:CreateDropdown({
		Name = 'Humanoid State',
		List = states
	})
	MoveMethod = Fly:CreateDropdown({
		Name = 'Move Mode',
		List = {'MoveDirection', 'Direct'},
		Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
	})
	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftControl', 'Space/LeftShift', 'E/Q', 'Space/Q', 'ButtonA/ButtonL2'},
		Tooltip = 'The key combination for going up & down'
	})
	Options.Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Options.TPFrequency = Fly:CreateSlider({
		Name = 'TP Frequency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseLength = Fly:CreateSlider({
		Name = 'Pulse Length',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Options.PulseDelay = Fly:CreateSlider({
		Name = 'Pulse Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	BounceLength = Fly:CreateSlider({
		Name = 'Bounce Length',
		Min = 0,
		Max = 30,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BounceDelay = Fly:CreateSlider({
		Name = 'Bounce Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPGround = Fly:CreateSlider({
		Name = 'Ground',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.1,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	FloatTPAir = Fly:CreateSlider({
		Name = 'Air',
		Min = 0,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Darker = true,
		Visible = false
	})
	Options.WallCheck = WallCheck
	PlatformStanding = Fly:CreateToggle({
		Name = 'PlatformStand',
		Function = function(callback)
			if Fly.Enabled then
				entitylib.character.Humanoid.PlatformStand = callback
			end
		end,
		Tooltip = 'Forces the character to look infront of the camera'
	})
	CustomProperties = Fly:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Default = true
	})
end)

run(function()
	local HighJump
	local Mode
	local Value
	local AutoDisable
	
	local function jump()
	
		if true then
			local root = entitylib.character.RootPart
	
			if Mode.Value == 'Velocity' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
			elseif Mode.Value == 'Impulse' then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				task.delay(0, function()
					root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
				end)
			else
				local yLevel = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
	
				repeat
					root.CFrame += Vector3.new(0, yLevel * 0.016, 0)
					yLevel = yLevel - (workspace.Gravity * 0.016)
	
					if Mode.Value == 'CFrame' then
						task.wait()
					end
				until yLevel <= 0
			end
		end
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
		Name = 'HighJump',
		Function = function(callback)
			if callback then
				if AutoDisable.Enabled then
					HighJump:Toggle()
					jump()
				else
					HighJump:Clean(runService.RenderStepped:Connect(function()
						if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
							jump()
						end
					end))
				end
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump higher'
	})
	
	Mode = HighJump:CreateDropdown({
		Name = 'Mode',
		List = {'Impulse', 'Velocity', 'CFrame', 'Instant'},
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump'
	})
	Value = HighJump:CreateSlider({
		Name = 'Velocity',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AutoDisable = HighJump:CreateToggle({
		Name = 'Auto Disable',
		Default = true
	})
end)

run(function()
	local HitBoxes
	local Targets
	local TargetPart
	local Expand
	local modified = {}
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				repeat
					for _, v in entitylib.List do
						if v.Targetable then
							if not Targets.Players.Enabled and v.Player then continue end
							if not Targets.NPCs.Enabled and v.NPC then continue end
							local part = v[TargetPart.Value]
							if not modified[part] then
								modified[part] = part.Size
							end
							part.Size = modified[part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
						end
					end
	
					task.wait()
				until not HitBoxes.Enabled
			else
				for i, v in modified do
					i.Size = v
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Expands entities hitboxes'
	})
	
	Targets = HitBoxes:CreateTargets({Players = true})
	TargetPart = HitBoxes:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local InfiniteJump
	local TPDown
	local Mode
	
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	InfiniteJump = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteJump',
		Function = function(callback)
			if callback then
				local jumps = 0
				InfiniteJump:Clean(inputService.JumpRequest:Connect(function()
					jumps += 1
					if jumps > 1 and Mode.Value == 'Velocity' then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, math.sqrt(2 * workspace.Gravity * entitylib.character.Humanoid.JumpHeight), root.AssemblyLinearVelocity.Z)
						jumps = 0
					elseif Mode.Value == 'Jump' then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
	
				local oldy = nil
				repeat
					if entitylib.isAlive and TPDown.Enabled and entitylib.character.AirTime then
						local root, airleft = entitylib.character.RootPart, (tick() - entitylib.character.AirTime)
						if oldy then
							root.CFrame = CFrame.lookAlong(Vector3.new(root.CFrame.X, oldy, root.CFrame.Z), root.CFrame.LookVector)
							oldy = nil
							task.wait(0.1)
						elseif airleft > 1.7 then
							rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
							local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayParams)
							if ray then
								oldy = root.Position.Y
								runService.PostSimulation:Wait()
								root.CFrame = CFrame.lookAlong(Vector3.new(root.CFrame.X, ray.Position.Y + (entitylib.character.HipHeight or 2.5), root.CFrame.Z), root.CFrame.LookVector)
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
		Name = 'Mode',
		List = {'Velocity', 'Jump'},
		Default = 'Jump'
	})
	TPDown = InfiniteJump:CreateToggle({Name = 'TP Down'})
end)

run(function()
	local Invisible
	local oldcf
	local animtrack
	local proper = true
	
	Invisible = vape.Categories.Blatant:CreateModule({
		Name = 'Invisible',
		Function = function(callback)
			if callback then
				if entitylib.isAlive then
					local isR15 = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15
					local anim = Instance.new('Animation')
					anim.AnimationId = 'rbxassetid://'..(isR15 and '18537363391' or '215384594')
					animtrack = entitylib.character.Humanoid.Animator:LoadAnimation(anim)
					animtrack.Priority = Enum.AnimationPriority.Action4
					animtrack:Play(0, 0.001, 0)
					anim:Destroy()
	
					task.delay(0, function()
						animtrack.TimePosition = isR15 and 0.77 or 0.38
					end)
				end
	
				oldcf = nil
				local bindKey = httpService:GenerateGUID(true)
				runService:BindToRenderStep(bindKey, 0, function()
					if entitylib.isAlive and oldcf then
						entitylib.character.RootPart.CFrame = oldcf
						animtrack:AdjustWeight(0.001)
					end
				end)
	
				Invisible:Clean(function()
					runService:UnbindFromRenderStep(bindKey)
				end)
	
				Invisible:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive then
						local isR15 = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15
						local root = entitylib.character.RootPart
						local cf = root.CFrame - Vector3.new(0, entitylib.character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)
						oldcf = root.CFrame
	
						root.CFrame = cf * CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)
						animtrack:AdjustWeight(100)
					end
				end))
	
				Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					local animator = char.Humanoid:WaitForChild('Animator', 1)
					if animator and Invisible.Enabled then
						oldroot = nil
						Invisible:Toggle()
						Invisible:Toggle()
					end
				end))
			else
				if animtrack then
					animtrack:Stop()
					animtrack:Destroy()
				end
	
				if entitylib.isAlive and oldcf then
					entitylib.character.RootPart.CFrame = oldcf
				end
			end
		end,
		Tooltip = 'Turns you invisible.'
	})
end)

run(function()
	local Jesus
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	
	Jesus = vape.Categories.Blatant:CreateModule({
		Name = 'Jesus',
		Function = function(callback)
			if callback then
				local terrain = workspace:FindFirstChildWhichIsA('Terrain')
				params.FilterDescendantsInstances = {terrain}
				local Platform = Instance.new('Part')
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.one
				Platform.Transparency = 1
				Platform.Parent = gameCamera
	
				Jesus:Clean(Platform)
				Jesus:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local ray = workspace:Raycast(root.Position, Vector3.new(0, -((root.Size.Y / 2) + entitylib.character.HipHeight + math.abs(root.AssemblyLinearVelocity.Y * 0.032)), 0), params)
						if ray and ray.Material == Enum.Material.Water then
							Platform.CFrame = CFrame.new(ray.Position)
						else
							Platform.CFrame = CFrame.new(10000, 10000, 10000)
						end
					end
				end))
			end
		end,
		Tooltip = 'Allow you to stand on terrain water'
	})
end)

run(function()
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
	local Overlay = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local interest, tool
					if not Mouse.Enabled or inputService:IsMouseButtonPressed(0) then
						tool = getTool()
						interest = tool and tool:FindFirstChildWhichIsA('TouchTransmitter', true) or nil
					end
					local attacked = {}
					if interest then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Limit = Max.Value
						})
	
						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
	
								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1
	
								if AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.GetRandomValue())
									tool:Activate()
								end
	
								if Lunge.Enabled and tool.GripUp.X == 0 then break end
								if delta.Magnitude > AttackRange.Value then continue end
	
								Overlay.FilterDescendantsInstances = {v.Character}
								for _, v in workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay) do
									firetouchinterest(interest.Parent, v, 1)
									firetouchinterest(interest.Parent, v, 0)
								end
							end
						end
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.01, vec.Z))
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				for _, v in Boxes do
					v.Adornee = nil
				end
	
				for _, v in Particles do
					v.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	
	Targets = Killaura:CreateTargets({Players = true})
	CPS = Killaura:CreateTwoSlider({
		Name = 'Attacks per Second',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 30,
		Default = 13,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 90
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Lunge = Killaura:CreateToggle({Name = 'Sword lunge only'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
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
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Default = 'rbxassetid://14736249347',
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Default = 0.2,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
end)

run(function()
	local Mode
	local Value
	local AutoDisable
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				local exempt = tick() + 0.1
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							if exempt < tick() and AutoDisable.Enabled then
								if LongJump.Enabled then
									LongJump:Toggle()
								end
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
	
						local root = entitylib.character.RootPart
						local dir = entitylib.character.Humanoid.MoveDirection * Value.Value
						if Mode.Value == 'Velocity' then
							root.AssemblyLinearVelocity = dir + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						elseif Mode.Value == 'Impulse' then
							local diff = (dir - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
							if diff.Magnitude > (dir == Vector3.zero and 10 or 2) then
								root:ApplyImpulse(diff * root.AssemblyMass)
							end
						else
							root.CFrame += dir * dt
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Lets you jump farther'
	})
	
	Mode = LongJump:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame'},
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
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
	local MouseTP
	local Mode
	local MovementMode
	local Length
	local Delay
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	MouseTP = vape.Categories.Blatant:CreateModule({
		Name = 'MouseTP',
		Function = function(callback)
			if callback then
				local position
				if Mode.Value == 'Mouse' then
					local ray = cloneref(lplr:GetMouse()).UnitRay
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
					ray = workspace:Raycast(ray.Origin, ray.Direction * 10000, rayCheck)
					position = ray and ray.Position + Vector3.new(0, entitylib.character.HipHeight or 2, 0)
				elseif Mode.Value == 'Waypoint' then
					local obj, dist, location = nil, math.huge, inputService:GetMouseLocation()
	
					for _, v in WaypointFolder:GetChildren() do
						local position, vis = gameCamera:WorldToViewportPoint(v.StudsOffsetWorldSpace)
						if not vis then continue end
	
						local mag = (location - Vector2.new(position.x, position.y)).Magnitude
						if mag < dist then
							obj, dist = v, mag
						end
					end
	
					local waypoint = obj
					position = waypoint and waypoint.StudsOffsetWorldSpace
				else
					local ent = entitylib.EntityMouse({
						Range = math.huge,
						Part = 'RootPart',
						Players = true
					})
					position = ent and ent.RootPart.Position
				end
	
				if not position then
					notif('MouseTP', 'No position found.', 5)
					MouseTP:Toggle()
					return
				end
	
				if MovementMode.Value ~= 'Lerp' then
					MouseTP:Toggle()
					if entitylib.isAlive then
						if MovementMode.Value == 'Motor' then
							motorMove(entitylib.character.RootPart, CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector))
						else
							entitylib.character.RootPart.CFrame = CFrame.lookAlong(position, entitylib.character.RootPart.CFrame.LookVector)
						end
					end
				else
					MouseTP:Clean(runService.Heartbeat:Connect(function()
						if entitylib.isAlive then
							entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
						end
					end))
	
					repeat
						if entitylib.isAlive then
							local direction = CFrame.lookAt(entitylib.character.RootPart.Position, position).LookVector * math.min((entitylib.character.RootPart.Position - position).Magnitude, Length.Value)
							entitylib.character.RootPart.CFrame += direction
							if (entitylib.character.RootPart.Position - position).Magnitude < 3 and MouseTP.Enabled then
								MouseTP:Toggle()
							end
						elseif MouseTP.Enabled then
							MouseTP:Toggle()
							notif('MouseTP', 'Character missing', 5, 'warning')
						end
	
						task.wait(Delay.Value)
					until not MouseTP.Enabled
				end
			end
		end,
		Tooltip = 'Teleports to a selected position.'
	})
	
	Mode = MouseTP:CreateDropdown({
		Name = 'Mode',
		List = {'Mouse', 'Player', 'Waypoint'}
	})
	MovementMode = MouseTP:CreateDropdown({
		Name = 'Movement',
		List = {'CFrame', 'Motor', 'Lerp'},
		Function = function(val)
			Length.Object.Visible = val == 'Lerp'
			Delay.Object.Visible = val == 'Lerp'
		end
	})
	Length = MouseTP:CreateSlider({
		Name = 'Length',
		Min = 0,
		Max = 150,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Delay = MouseTP:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)

run(function()
	local Mode
	local StudLimit = {Object = {}}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local overlapCheck = OverlapParams.new()
	overlapCheck.MaxParts = 9e9
	local modified, fflag = {}
	local teleported
	
	local Functions = {
		Part = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			overlapCheck.FilterDescendantsInstances = chars
	
			local parts = workspace:GetPartBoundsInBox(entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0), entitylib.character.RootPart.Size + Vector3.new(7, entitylib.character.HipHeight, 7), overlapCheck)
			for _, v in parts do
				if v.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[v] = true
					v.CanCollide = false
				end
			end
	
			for i in modified do
				if not table.find(parts, i) then
					modified[i] = nil
					i.CanCollide = true
				end
			end
		end,
		Character = function()
			for _, v in lplr.Character:GetDescendants() do
				if v:IsA('BasePart') and v.CanCollide and (not Spider.Enabled or SpiderShift) then
					modified[v] = true
					v.CanCollide = Spider.Enabled and not SpiderShift
				end
			end
		end,
		CFrame = function()
			local chars = {gameCamera, lplr.Character}
			for _, v in entitylib.List do
				table.insert(chars, v.Character)
			end
			rayCheck.FilterDescendantsInstances = chars
			overlapCheck.FilterDescendantsInstances = chars
	
			local ray = workspace:Raycast(entitylib.character.Head.CFrame.Position, entitylib.character.Humanoid.MoveDirection * 1.1, rayCheck)
			if ray and (not Spider.Enabled or SpiderShift) then
				local ray = ray
				local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
	
				for _, v in Enum.NormalId:GetEnumItems() do
					local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(v)):Dot(ray.Normal)
					if dot > mag then
						mag, closest = dot, v
					end
				end
	
				local phaseDirection = Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
				if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
					local root = entitylib.character.RootPart
					local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))
					if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
						if Mode.Value == 'Motor' then
							motorMove(root, dest)
						else
							root.CFrame = dest
						end
					end
				end
			end
		end,
		FFlag = function()
			if teleported then return end
			setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
			fflag = true
		end
	}
	Functions.Motor = Functions.CFrame
	
	Phase = vape.Categories.Blatant:CreateModule({
		Name = 'Phase',
		Function = function(callback)
			if callback then
				Phase:Clean(runService.Stepped:Connect(function()
					if entitylib.isAlive then
						Functions[Mode.Value]()
					end
				end))
	
				if Mode.Value == 'FFlag' then
					Phase:Clean(lplr.OnTeleport:Connect(function()
						teleported = true
						setfflag('AssemblyExtentsExpansionStudHundredth', '30')
					end))
				end
			else
				if fflag then
					setfflag('AssemblyExtentsExpansionStudHundredth', '30')
				end
				for i in modified do
					i.CanCollide = true
				end
				table.clear(modified)
				fflag = nil
			end
		end,
		Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)'
	})
	
	Mode = Phase:CreateDropdown({
		Name = 'Mode',
		List = {'Part', 'Character', 'CFrame', 'Motor', 'FFlag'},
		Function = function(val)
			StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
			if fflag then
				setfflag('AssemblyExtentsExpansionStudHundredth', '30')
			end
			for i in modified do
				i.CanCollide = true
			end
			table.clear(modified)
			fflag = nil
		end,
		Tooltip = 'Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions'
	})
	StudLimit = Phase:CreateSlider({
		Name = 'Wall Size',
		Min = 1,
		Max = 20,
		Default = 5,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Speed
	local Mode
	local Options
	local AutoJump
	local AutoJumpCustom
	local AutoJumpValue
	local w, s, a, d = 0, 0, 0, 0
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback and CustomProperties.Enabled or nil
			updateVelocity()
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not Fly.Enabled and not vape.Modules.LongJump.Enabled then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local movevec = TargetStrafeVector or Options.MoveMethod.Value == 'Direct' and calculateMoveVector(Vector3.new(a + d, 0, w + s)) or entitylib.character.Humanoid.MoveDirection
						SpeedMethods[Mode.Value](Options, movevec, dt)
						if AutoJump.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and movevec ~= Vector3.zero then
							if AutoJumpCustom.Enabled then
								local velocity = entitylib.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
								entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, AutoJumpValue.Value, velocity.Z)
							else
								entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
							end
						end
					end
				end))
	
				w, s, a, d = inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				for _, v in {'InputBegan', 'InputEnded'} do
					Speed:Clean(inputService[v]:Connect(function(input)
						if not inputService:GetFocusedTextBox() then
							if input.KeyCode == Enum.KeyCode.W then
								w = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.S then
								s = v == 'InputBegan' and 1 or 0
							elseif input.KeyCode == Enum.KeyCode.A then
								a = v == 'InputBegan' and -1 or 0
							elseif input.KeyCode == Enum.KeyCode.D then
								d = v == 'InputBegan' and 1 or 0
							end
						end
					end))
				end
			else
				if Options.WalkSpeed and entitylib.isAlive then
					entitylib.character.Humanoid.WalkSpeed = Options.WalkSpeed
				end
				Options.WalkSpeed = nil
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = SpeedMethodList,
		Function = function(val)
			Options.WallCheck.Object.Visible = val == 'CFrame' or val == 'TP'
			Options.TPFrequency.Object.Visible = val == 'TP'
			Options.PulseLength.Object.Visible = val == 'Pulse'
			Options.PulseDelay.Object.Visible = val == 'Pulse'
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Tooltip = 'Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games.'
	})
	Options = {
		MoveMethod = Speed:CreateDropdown({
			Name = 'Move Mode',
			List = {'MoveDirection', 'Direct'},
			Tooltip = 'MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector'
		}),
		Value = Speed:CreateSlider({
			Name = 'Speed',
			Min = 1,
			Max = 150,
			Default = 50,
			Suffix = function(val)
				return val == 1 and 'stud' or 'studs'
			end
		}),
		TPFrequency = Speed:CreateSlider({
			Name = 'TP Frequency',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		PulseLength = Speed:CreateSlider({
			Name = 'Pulse Length',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		PulseDelay = Speed:CreateSlider({
			Name = 'Pulse Delay',
			Min = 0,
			Max = 1,
			Decimal = 100,
			Darker = true,
			Visible = false,
			Suffix = function(val)
				return val == 1 and 'second' or 'seconds'
			end
		}),
		WallCheck = Speed:CreateToggle({
			Name = 'Wall Check',
			Default = true,
			Darker = true,
			Visible = false
		}),
		TPTiming = tick(),
		rayCheck = RaycastParams.new()
	}
	Options.rayCheck.RespectCanCollide = true
	CustomProperties = Speed:CreateToggle({
		Name = 'Custom Properties',
		Function = function()
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AutoJumpCustom.Object.Visible = callback
		end
	})
	AutoJumpCustom = Speed:CreateToggle({
		Name = 'Custom Jump',
		Function = function(callback)
			AutoJumpValue.Object.Visible = callback
		end,
		Tooltip = 'Allows you to adjust the jump power',
		Darker = true,
		Visible = false
	})
	AutoJumpValue = Speed:CreateSlider({
		Name = 'Jump Power',
		Min = 1,
		Max = 50,
		Default = 30,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Mode
	local Value
	local State
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local Active, Truss
	
	Spider = vape.Categories.Blatant:CreateModule({
		Name = 'Spider',
		Function = function(callback)
			if callback then
				if Truss then
					Truss.Parent = gameCamera
				end
	
				Spider:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local chars = {gameCamera, lplr.Character, Truss}
						for _, v in entitylib.List do
							table.insert(chars, v.Character)
						end
	
						SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
						rayCheck.FilterDescendantsInstances = chars
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if Mode.Value ~= 'Part' then
							local vec = entitylib.character.Humanoid.MoveDirection * 2.5
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
							if Active and not ray then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
							end
	
							Active = ray
							if Active and ray.Normal.Y == 0 then
								if not Phase.Enabled or not SpiderShift then
									if State.Enabled then
										entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
									end
	
									root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
									if Mode.Value == 'CFrame' then
										root.CFrame += Vector3.new(0, Value.Value * dt, 0)
									elseif Mode.Value == 'Impulse' then
										root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
									else
										root.AssemblyLinearVelocity += Vector3.new(0, Value.Value, 0)
									end
								end
							end
						else
							local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), entitylib.character.RootPart.CFrame.LookVector * 2, rayCheck)
							if ray and (not Phase.Enabled or not SpiderShift) then
								Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
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
		Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
	})
	
	Mode = Spider:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'Impulse', 'CFrame', 'Part'},
		Function = function(val)
			Value.Object.Visible = val ~= 'Part'
			State.Object.Visible = val ~= 'Part'
			if Truss then
				Truss:Destroy()
				Truss = nil
			end
			if val == 'Part' then
				Truss = Instance.new('TrussPart')
				Truss.Size = Vector3.new(2, 2, 2)
				Truss.Transparency = 1
				Truss.Anchored = true
				Truss.Parent = Spider.Enabled and gameCamera or nil
			end
		end,
		Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you'
	})
	Value = Spider:CreateSlider({
		Name = 'Speed',
		Min = 0,
		Max = 100,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	State = Spider:CreateToggle({
		Name = 'Climb State',
		Darker = true
	})
end)

run(function()
	local SpinBot
	local Mode
	local XToggle
	local YToggle
	local ZToggle
	local Value
	local AngularVelocity
	
	SpinBot = vape.Categories.Blatant:CreateModule({
		Name = 'SpinBot',
		Function = function(callback)
			if callback then
				SpinBot:Clean(runService.PreSimulation:Connect(function()
					if entitylib.isAlive then
						if Mode.Value == 'RotVelocity' then
							local originalRotVelocity = entitylib.character.RootPart.RotVelocity
							entitylib.character.Humanoid.AutoRotate = false
							entitylib.character.RootPart.RotVelocity = Vector3.new(XToggle.Enabled and Value.Value or originalRotVelocity.X, YToggle.Enabled and Value.Value or originalRotVelocity.Y, ZToggle.Enabled and Value.Value or originalRotVelocity.Z)
						elseif Mode.Value == 'CFrame' then
							local val = math.rad((tick() * (20 * Value.Value)) % 360)
							local x, y, z = entitylib.character.RootPart.CFrame:ToOrientation()
							entitylib.character.RootPart.CFrame = CFrame.new(entitylib.character.RootPart.Position) * CFrame.Angles(XToggle.Enabled and val or x, YToggle.Enabled and val or y, ZToggle.Enabled and val or z)
						elseif AngularVelocity then
							AngularVelocity.Parent = entitylib.isAlive and entitylib.character.RootPart
							AngularVelocity.MaxTorque = Vector3.new(XToggle.Enabled and math.huge or 0, YToggle.Enabled and math.huge or 0, ZToggle.Enabled and math.huge or 0)
							AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
						end
					end
				end))
			else
				if entitylib.isAlive and Mode.Value == 'RotVelocity' then
					entitylib.character.Humanoid.AutoRotate = true
				end
	
				if AngularVelocity then
					AngularVelocity.Parent = nil
				end
			end
		end,
		Tooltip = 'Makes your character spin around in circles (does not work in first person)'
	})
	
	Mode = SpinBot:CreateDropdown({
		Name = 'Mode',
		List = {'CFrame', 'RotVelocity', 'BodyMover'},
		Function = function(val)
			if AngularVelocity then
				AngularVelocity:Destroy()
				AngularVelocity = nil
			end
			AngularVelocity = val == 'BodyMover' and Instance.new('BodyAngularVelocity') or nil
		end,
		Tooltip = 'CFrame - Directly adjusts your characters angle\nRotVelocity - Sets the rotation velocity so that you spin\nBodyMover - Uses body movers to edit your rotation velocity'
	})
	Value = SpinBot:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 100,
		Default = 40
	})
	XToggle = SpinBot:CreateToggle({Name = 'Spin X'})
	YToggle = SpinBot:CreateToggle({
		Name = 'Spin Y',
		Default = true
	})
	ZToggle = SpinBot:CreateToggle({Name = 'Spin Z'})
end)

run(function()
	local Swim
	local terrain = cloneref(workspace:FindFirstChildWhichIsA('Terrain'))
	local lastpos = Region3.new(Vector3.zero, Vector3.zero)
	
	Swim = vape.Categories.Blatant:CreateModule({
		Name = 'Swim',
		Function = function(callback)
			if callback then
				Swim:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local moving = entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
						local rootvelo = root.AssemblyLinearVelocity
						local space = inputService:IsKeyDown(Enum.KeyCode.Space)
	
						if terrain then
							local factor = (moving or space) and Vector3.new(6, 6, 6) or Vector3.new(2, 1, 2)
							local pos = root.Position - Vector3.new(0, 1, 0)
							local newpos = Region3.new(pos - factor, pos + factor):ExpandToGrid(4)
							terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
							terrain:FillRegion(newpos, 4, Enum.Material.Water)
							lastpos = newpos
						end
					end
				end))
			else
				if terrain and lastpos then
					terrain:ReplaceMaterial(lastpos, 4, Enum.Material.Water, Enum.Material.Air)
				end
			end
		end,
		Tooltip = 'Lets you swim midair'
	})
end)

run(function()
	local TargetStrafe
	local Targets
	local SearchRange
	local StrafeRange
	local YFactor
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	TargetStrafe = vape.Categories.Blatant:CreateModule({
		Name = 'TargetStrafe',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
					if not suc then
						module = {}
					end
				end
	
				old = module.moveFunction
				local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
				module.moveFunction = function(self, vec, face)
					local wallcheck = Targets.Walls.Enabled
					local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
						Range = SearchRange.Value,
						Wallcheck = wallcheck,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value
					})
	
					if ent then
						local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
							local factor, localPosition = 0, root.Position
							if ent ~= oldent then
								ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
							end
	
							local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
							local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
							local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
							local startRay, endRay = entityPos, newPos
	
							if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
								startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
							end
	
							local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
							if (localPosition - newPos).Magnitude < 3 or ray then
								factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
								if ray then
									newPos = ray.Position + (ray.Normal * 1.5)
									factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
								end
							end
	
							if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
								newPos = entityPos
								factor = 40
							end
	
							ang += factor % 360
							vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
							vec = vec == vec and vec or Vector3.zero
							TargetStrafeVector = vec
						else
							ent = nil
						end
					end
	
					TargetStrafeVector = ent and vec or nil
					oldent = ent
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
				TargetStrafeVector = nil
			end
		end,
		Tooltip = 'Automatically strafes around the opponent'
	})
	
	Targets = TargetStrafe:CreateTargets({
		Players = true,
		Walls = true
	})
	SearchRange = TargetStrafe:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	StrafeRange = TargetStrafe:CreateSlider({
		Name = 'Strafe Range',
		Min = 1,
		Max = 30,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	YFactor = TargetStrafe:CreateSlider({
		Name = 'Y Factor',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local Timer
	local Value
	
	Timer = vape.Categories.Blatant:CreateModule({
		Name = 'Timer',
		Function = function(callback)
			if callback then
				setfflag('SimEnableStepPhysics', 'True')
				setfflag('SimEnableStepPhysicsSelective', 'True')
	
				Timer:Clean(runService.RenderStepped:Connect(function(dt)
					if Value.Value > 1 then
						runService:Pause()
						workspace:StepPhysics(dt * (Value.Value - 1), {entitylib.character.RootPart})
						runService:Run()
					end
				end))
			end
		end,
		Tooltip = 'Change the game speed.'
	})
	
	Value = Timer:CreateSlider({
		Name = 'Value',
		Min = 1,
		Max = 3,
		Decimal = 10
	})
end)

run(function()
	local Arrows
	local Targets
	local Color
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local arrow = Instance.new('ImageLabel')
		arrow.Size = UDim2.fromOffset(256, 256)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.BorderSizePixel = 0
		arrow.Visible = false
		arrow.Image = getvapeasset('kingvape/assets/new/arrowmodule.png')
		arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		arrow.Parent = Folder
		Reference[ent] = arrow
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	local function ColorFunc(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.ImageColor3 = entitylib.getEntityColor(i) or color
		end
	end
	
	local function Loop()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		for i, v in Reference do
			if Distance.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					v.Visible = false
					continue
				end
			end
	
			local _, rootVis = gameCamera:WorldToScreenPoint(i.RootPart.Position)
			v.Visible = not rootVis
			if rootVis then continue end
	
			local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(i.RootPart.Position)
			v.Rotation = math.deg(math.atan2(dir.Z, dir.X))
		end
	end
	
	Arrows = vape.Categories.Render:CreateModule({
		Name = 'Arrows',
		Function = function(callback)
			if callback then
				Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then Removed(v) end
					Added(v)
				end
				Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then Removed(ent) end
					Added(ent)
				end))
				Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Arrows:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Draws arrows on screen when entities\nare out of your field of view.'
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
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Arrows.Enabled then
				ColorFunc(hue, sat, val)
			end
		end
	})
	Teammates = Arrows:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Arrows.Enabled then
				Arrows:Toggle()
				Arrows:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = Arrows:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Arrows:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)

run(function()
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
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		if Mode.Value == 'Highlight' then
			local cham = Instance.new('Highlight')
			cham.Adornee = ent.Character
			cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
			cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
			cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
			cham.FillTransparency = FillTransparency.Value
			cham.OutlineTransparency = OutlineTransparency.Value
			cham.Parent = Folder
			Reference[ent] = cham
		else
			local chams = {}
			for _, v in ent.Character:GetChildren() do
				if v:IsA('BasePart') and (ent.NPC or v.Name:find('Arm') or v.Name:find('Leg') or v.Name:find('Hand') or v.Name:find('Feet') or v.Name:find('Torso') or v.Name == 'Head') then
					local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
					if v.Name == 'Head' then
						box.Radius = 0.75
					else
						box.Size = v.Size
					end
					box.AlwaysOnTop = Walls.Enabled
					box.Adornee = v
					box.ZIndex = 0
					box.Transparency = FillTransparency.Value
					box.Color3 = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
					box.Parent = Folder
					table.insert(chams, box)
				end
			end
			Reference[ent] = chams
		end
	end
	
	local function Removed(ent)
		if Reference[ent] then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			if type(Reference[ent]) == 'table' then
				for _, v in Reference[ent] do
					v:Destroy()
				end
				table.clear(Reference[ent])
			else
				Reference[ent]:Destroy()
			end
			Reference[ent] = nil
		end
	end
	
	Chams = vape.Categories.Render:CreateModule({
		Name = 'Chams',
		Function = function(callback)
			if callback then
				Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for i, v in Reference do
						local color = entitylib.getEntityColor(i) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
						if type(v) == 'table' then
							for _, v2 in v do v2.Color3 = color end
						else
							v.FillColor = color
						end
					end
				end))
	
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Render players through walls'
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
		Name = 'Mode',
		List = {'Highlight', 'BoxHandles'},
		Function = function(val)
			OutlineColor.Object.Visible = val == 'Highlight'
			OutlineTransparency.Object.Visible = val == 'Highlight'
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end
	})
	FillColor = Chams:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for i, v in Reference do
				local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
				if type(v) == 'table' then
					for _, v2 in v do v2.Color3 = color end
				else
					v.FillColor = color
				end
			end
		end
	})
	OutlineColor = Chams:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Function = function(hue, sat, val)
			for i, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineColor = Color3.fromHSV(hue, sat, val)
				end
			end
		end,
		Darker = true
	})
	FillTransparency = Chams:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do v2.Transparency = val end
				else
					v.FillTransparency = val
				end
			end
		end,
		Decimal = 10,
		Default = 0.5
	})
	OutlineTransparency = Chams:CreateSlider({
		Name = 'Outline Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, v in Reference do
				if type(v) ~= 'table' then
					v.OutlineTransparency = val
				end
			end
		end,
		Decimal = 10,
		Default = 0.5,
		Darker = true
	})
	Walls = Chams:CreateToggle({
		Name = 'Render Walls',
		Function = function(callback)
			for _, v in Reference do
				if type(v) == 'table' then
					for _, v2 in v do
						v2.AlwaysOnTop = callback
					end
				else
					v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
				end
			end
		end,
		Default = true
	})
	Teammates = Chams:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Chams.Enabled then
				Chams:Toggle()
				Chams:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)

run(function()
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
	local methodused
	
	local function ESPWorldToViewport(pos)
		local newpos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(gameCamera.CFrame:PointToObjectSpace(pos)))
		return Vector2.new(newpos.X, newpos.Y)
	end
	
	local ESPAdded = {
		Drawing2D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Main = Drawing.new('Square')
			EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
			EntityESP.Main.ZIndex = 2
			EntityESP.Main.Filled = false
			EntityESP.Main.Thickness = 1
			EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	
			if BoundingBox.Enabled then
				EntityESP.Border = Drawing.new('Square')
				EntityESP.Border.Transparency = 0.35
				EntityESP.Border.ZIndex = 1
				EntityESP.Border.Thickness = 1
				EntityESP.Border.Filled = false
				EntityESP.Border.Color = Color3.new()
				EntityESP.Border2 = Drawing.new('Square')
				EntityESP.Border2.Transparency = 0.35
				EntityESP.Border2.ZIndex = 1
				EntityESP.Border2.Thickness = 1
				EntityESP.Border2.Filled = Filled.Enabled
				EntityESP.Border2.Color = Color3.new()
			end
	
			if HealthBar.Enabled then
				EntityESP.HealthLine = Drawing.new('Line')
				EntityESP.HealthLine.Thickness = 1
				EntityESP.HealthLine.ZIndex = 2
				EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				EntityESP.HealthBorder = Drawing.new('Line')
				EntityESP.HealthBorder.Thickness = 3
				EntityESP.HealthBorder.Transparency = 0.35
				EntityESP.HealthBorder.ZIndex = 1
				EntityESP.HealthBorder.Color = Color3.new()
			end
	
			if Name.Enabled then
				if Background.Enabled then
					EntityESP.TextBKG = Drawing.new('Square')
					EntityESP.TextBKG.Transparency = 0.35
					EntityESP.TextBKG.ZIndex = 0
					EntityESP.TextBKG.Thickness = 1
					EntityESP.TextBKG.Filled = true
					EntityESP.TextBKG.Color = Color3.new()
				end
				EntityESP.Drop = Drawing.new('Text')
				EntityESP.Drop.Color = Color3.new()
				EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
				EntityESP.Drop.ZIndex = 1
				EntityESP.Drop.Center = true
				EntityESP.Drop.Size = 20
				EntityESP.Text = Drawing.new('Text')
				EntityESP.Text.Text = EntityESP.Drop.Text
				EntityESP.Text.ZIndex = 2
				EntityESP.Text.Color = EntityESP.Main.Color
				EntityESP.Text.Center = true
				EntityESP.Text.Size = 20
			end
			Reference[ent] = EntityESP
		end,
		Drawing3D = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Line1 = Drawing.new('Line')
			EntityESP.Line2 = Drawing.new('Line')
			EntityESP.Line3 = Drawing.new('Line')
			EntityESP.Line4 = Drawing.new('Line')
			EntityESP.Line5 = Drawing.new('Line')
			EntityESP.Line6 = Drawing.new('Line')
			EntityESP.Line7 = Drawing.new('Line')
			EntityESP.Line8 = Drawing.new('Line')
			EntityESP.Line9 = Drawing.new('Line')
			EntityESP.Line10 = Drawing.new('Line')
			EntityESP.Line11 = Drawing.new('Line')
			EntityESP.Line12 = Drawing.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 1
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end,
		DrawingSkeleton = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local EntityESP = {}
			EntityESP.Head = Drawing.new('Line')
			EntityESP.HeadFacing = Drawing.new('Line')
			EntityESP.Torso = Drawing.new('Line')
			EntityESP.UpperTorso = Drawing.new('Line')
			EntityESP.LowerTorso = Drawing.new('Line')
			EntityESP.LeftArm = Drawing.new('Line')
			EntityESP.RightArm = Drawing.new('Line')
			EntityESP.LeftLeg = Drawing.new('Line')
			EntityESP.RightLeg = Drawing.new('Line')
	
			local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			for _, v in EntityESP do
				v.Thickness = 2
				v.Color = color
			end
	
			Reference[ent] = EntityESP
		end
	}
	
	local ESPRemoved = {
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				for _, v in EntityESP do
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
		Drawing2D = function(ent)
			local EntityESP = Reference[ent]
			if EntityESP then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
	
				if EntityESP.HealthLine then
					EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				end
	
				if EntityESP.Text then
					EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
					EntityESP.Drop.Text = EntityESP.Text.Text
				end
			end
		end
	}
	
	local ColorFunc = {
		Drawing2D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Main.Color = entitylib.getEntityColor(i) or color
				if v.Text then
					v.Text.Color = v.Main.Color
				end
			end
		end,
		Drawing3D = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				local playercolor = entitylib.getEntityColor(i) or color
				for _, v2 in v do
					v2.Color = playercolor
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
	
			for i, v in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, v in v do
							v.Visible = false
						end
						continue
					end
				end
	
				local rootPos, rootVis = gameCamera:WorldToViewportPoint(i.RootPart.Position)
				for _, v in v do
					v.Visible = rootVis
				end
				if not rootVis then continue end
	
				local facing = CFrame.lookAlong(i.RootPart.Position, gameCamera.CFrame.LookVector)
				local topPos = gameCamera:WorldToViewportPoint((facing * CFrame.new(2, i.HipHeight, 0)).p)
				local bottomPos = gameCamera:WorldToViewportPoint((facing * CFrame.new(-2, -i.HipHeight - 1, 0)).p)
				local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
				local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
				v.Main.Position = Vector2.new(posx, posy) // 1
				v.Main.Size = Vector2.new(sizex, sizey) // 1
				if v.Border then
					v.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
					v.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
					v.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
					v.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
				end
	
				if v.HealthLine then
					local healthposy = sizey * math.clamp(i.Health / i.MaxHealth, 0, 1)
					v.HealthLine.Visible = i.Health > 0
					v.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
					v.HealthLine.To = Vector2.new(posx - 6, posy) // 1
					v.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
					v.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
				end
	
				if v.Text then
					v.Text.Position = Vector2.new(posx + (sizex / 2), posy + (sizey - 28)) // 1
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
	
			for i, v in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, v in v do
							v.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(i.RootPart.Position)
				for _, v in v do
					v.Visible = rootVis
				end
				if not rootVis then continue end
	
				local rootPosition = i.RootPart.Position
				local point1 = ESPWorldToViewport(rootPosition + Vector3.new(1.5, i.HipHeight, 1.5))
				local point2 = ESPWorldToViewport(rootPosition + Vector3.new(1.5, -i.HipHeight, 1.5))
				local point3 = ESPWorldToViewport(rootPosition + Vector3.new(-1.5, i.HipHeight, 1.5))
				local point4 = ESPWorldToViewport(rootPosition + Vector3.new(-1.5, -i.HipHeight, 1.5))
				local point5 = ESPWorldToViewport(rootPosition + Vector3.new(1.5, i.HipHeight, -1.5))
				local point6 = ESPWorldToViewport(rootPosition + Vector3.new(1.5, -i.HipHeight, -1.5))
				local point7 = ESPWorldToViewport(rootPosition + Vector3.new(-1.5, i.HipHeight, -1.5))
				local point8 = ESPWorldToViewport(rootPosition + Vector3.new(-1.5, -i.HipHeight, -1.5))
				v.Line1.From = point1
				v.Line1.To = point2
				v.Line2.From = point3
				v.Line2.To = point4
				v.Line3.From = point5
				v.Line3.To = point6
				v.Line4.From = point7
				v.Line4.To = point8
				v.Line5.From = point1
				v.Line5.To = point3
				v.Line6.From = point1
				v.Line6.To = point5
				v.Line7.From = point5
				v.Line7.To = point7
				v.Line8.From = point7
				v.Line8.To = point3
				v.Line9.From = point2
				v.Line9.To = point4
				v.Line10.From = point2
				v.Line10.To = point6
				v.Line11.From = point6
				v.Line11.To = point8
				v.Line12.From = point8
				v.Line12.To = point4
			end
		end,
		DrawingSkeleton = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			for i, v in Reference do
				if Distance.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						for _, v in v do
							v.Visible = false
						end
						continue
					end
				end
	
				local _, rootVis = gameCamera:WorldToViewportPoint(i.RootPart.Position)
				for _, v in v do
					v.Visible = rootVis
				end
				if not rootVis then continue end
	
				local rigcheck = i.Humanoid.RigType == Enum.HumanoidRigType.R6
				pcall(function()
					local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
					local head = ESPWorldToViewport((i.Head.CFrame).p)
					local headfront = ESPWorldToViewport((i.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
					local toplefttorso = ESPWorldToViewport((i.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
					local toprighttorso = ESPWorldToViewport((i.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
					local toptorso = ESPWorldToViewport((i.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
					local bottomtorso = ESPWorldToViewport((i.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
					local bottomlefttorso = ESPWorldToViewport((i.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
					local bottomrighttorso = ESPWorldToViewport((i.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
					local leftarm = ESPWorldToViewport((i.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
					local rightarm = ESPWorldToViewport((i.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
					local leftleg = ESPWorldToViewport((i.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
					local rightleg = ESPWorldToViewport((i.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
					v.Head.From = toptorso
					v.Head.To = head
					v.HeadFacing.From = head
					v.HeadFacing.To = headfront
					v.UpperTorso.From = toplefttorso
					v.UpperTorso.To = toprighttorso
					v.Torso.From = toptorso
					v.Torso.To = bottomtorso
					v.LowerTorso.From = bottomlefttorso
					v.LowerTorso.To = bottomrighttorso
					v.LeftArm.From = toplefttorso
					v.LeftArm.To = leftarm
					v.RightArm.From = toprighttorso
					v.RightArm.To = rightarm
					v.LeftLeg.From = bottomlefttorso
					v.LeftLeg.To = leftleg
					v.RightLeg.From = bottomrighttorso
					v.RightLeg.To = rightleg
				end)
			end
		end
	}
	
	ESP = vape.Categories.Render:CreateModule({
		Name = 'ESP',
		Function = function(callback)
			if callback then
				methodused = 'Drawing'..Method.Value
				if ESPRemoved[methodused] then
					ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
				end
				if ESPAdded[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							ESPRemoved[methodused](v)
						end
						ESPAdded[methodused](v)
					end
					ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							ESPRemoved[methodused](ent)
						end
						ESPAdded[methodused](ent)
					end))
				end
				if ESPUpdated[methodused] then
					ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
					for _, v in entitylib.List do
						ESPUpdated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if ESPLoop[methodused] then
					ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
				end
			else
				if ESPRemoved[methodused] then
					for i in Reference do
						ESPRemoved[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
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
		Name = 'Mode',
		List = {'2D', '3D', 'Skeleton'},
		Function = function(val)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			BoundingBox.Object.Visible = (val == '2D')
			Filled.Object.Visible = (val == '2D')
			HealthBar.Object.Visible = (val == '2D')
			Name.Object.Visible = (val == '2D')
			DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
			Background.Object.Visible = Name.Object.Visible and Name.Enabled
		end
	})
	Color = ESP:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if ESP.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	BoundingBox = ESP:CreateToggle({
		Name = 'Bounding Box',
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
		Name = 'Filled',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	HealthBar = ESP:CreateToggle({
		Name = 'Health Bar',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Name = ESP:CreateToggle({
		Name = 'Name',
		Function = function(callback)
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
			DisplayName.Object.Visible = callback
			Background.Object.Visible = callback
		end,
		Darker = true
	})
	DisplayName = ESP:CreateToggle({
		Name = 'Use Displayname',
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
		Name = 'Show Background',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Darker = true
	})
	Teammates = ESP:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if ESP.Enabled then
				ESP:Toggle()
				ESP:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	Distance = ESP:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = ESP:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local Fullbright
	local Mode
	local oldsettings = {}
	local flag
	
	local function ChangeLighting(prop)
		if flag then
			return
		end
	
		flag = true
		lightingService.Ambient = Color3.new(1, 1, 1)
		lightingService.OutdoorAmbient = Color3.new(1, 1, 1)
		lightingService.Brightness = 3
		runService.RenderStepped:Wait()
		flag = false
	end
	
	Fullbright = vape.Categories.Render:CreateModule({
		Name = 'Fullbright',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Lighting' then
					for _, v in {'Ambient', 'OutdoorAmbient', 'Brightness'} do
						oldsettings[v] = lightingService[v]
					end
	
					Fullbright:Clean(lightingService.Changed:Connect(ChangeLighting))
					task.spawn(ChangeLighting)
				else
					local inst = Instance.new('PointLight')
					inst.Range = 1000
					Fullbright:Clean(inst)
	
					repeat
						inst.Parent = entitylib.isAlive and entitylib.character.RootPart or nil
						task.wait(0.1)
					until not Fullbright.Enabled
				end
			else
				flag = false
				for i, v in oldsettings do
					lightingService[i] = v
				end
				table.clear(oldsettings)
			end
		end,
		Tooltip = 'Increase the lighting of the world around you.'
	})
	
	Mode = Fullbright:CreateDropdown({
		Name = 'Mode',
		List = {'Lighting', 'PointLight'},
		Function = function()
			if Fullbright.Enabled then
				Fullbright:Toggle()
				Fullbright:Toggle()
			end
		end
	})
end)

run(function()
	local GamingChair = {Enabled = false}
	local Color
	local wheelpositions = {
		Vector3.new(-0.8, -0.6, -0.18),
		Vector3.new(0.1, -0.6, -0.88),
		Vector3.new(0, -0.6, 0.7)
	}
	local chairhighlight
	local currenttween
	local movingsound
	local flyingsound
	local chairanim
	local chair
	
	GamingChair = vape.Categories.Render:CreateModule({
		Name = 'GamingChair',
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				chair = Instance.new('MeshPart')
				chair.Color = Color3.fromRGB(21, 21, 21)
				chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
				chair.CanCollide = false
				chair.Massless = true
				chair.MeshId = 'rbxassetid://12972961089'
				chair.Material = Enum.Material.SmoothPlastic
				chair.Parent = workspace
				movingsound = Instance.new('Sound')
				movingsound.Volume = 0.4
				movingsound.Looped = true
				movingsound.Parent = workspace
				flyingsound = Instance.new('Sound')
				flyingsound.Volume = 0.4
				flyingsound.Looped = true
				flyingsound.Parent = workspace
				local chairweld = Instance.new('WeldConstraint')
				chairweld.Part0 = chair
				chairweld.Parent = chair
				if entitylib.isAlive then
					chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
					chairweld.Part1 = entitylib.character.RootPart
				end
				chairhighlight = Instance.new('Highlight')
				chairhighlight.FillTransparency = 1
				chairhighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				chairhighlight.DepthMode = Enum.HighlightDepthMode.Occluded
				chairhighlight.OutlineTransparency = 0.2
				chairhighlight.Parent = chair
				local chairarms = Instance.new('MeshPart')
				chairarms.Color = chair.Color
				chairarms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
				chairarms.CFrame = chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
				chairarms.MeshId = 'rbxassetid://12972673898'
				chairarms.CanCollide = false
				chairarms.Parent = chair
				local chairarmsweld = Instance.new('WeldConstraint')
				chairarmsweld.Part0 = chairarms
				chairarmsweld.Part1 = chair
				chairarmsweld.Parent = chair
				local chairlegs = Instance.new('MeshPart')
				chairlegs.Color = chair.Color
				chairlegs.Name = 'Legs'
				chairlegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
				chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
				chairlegs.MeshId = 'rbxassetid://13003181606'
				chairlegs.CanCollide = false
				chairlegs.Parent = chair
				local chairfan = Instance.new('MeshPart')
				chairfan.Color = chair.Color
				chairfan.Name = 'Fan'
				chairfan.Size = Vector3.zero
				chairfan.CFrame = chair.CFrame * CFrame.new(0, -1.873, 0)
				chairfan.MeshId = 'rbxassetid://13004977292'
				chairfan.CanCollide = false
				chairfan.Parent = chair
				local trails = {}
				for _, v in wheelpositions do
					local attachment = Instance.new('Attachment')
					attachment.Position = v
					attachment.Parent = chairlegs
					local attachment2 = Instance.new('Attachment')
					attachment2.Position = v + Vector3.new(0, 0, 0.18)
					attachment2.Parent = chairlegs
					local trail = Instance.new('Trail')
					trail.Texture = 'http://www.roblox.com/asset/?id=13005168530'
					trail.TextureMode = Enum.TextureMode.Static
					trail.Transparency = NumberSequence.new(0.5)
					trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
					trail.Attachment0 = attachment
					trail.Attachment1 = attachment2
					trail.Lifetime = 20
					trail.MaxLength = 60
					trail.MinLength = 0.1
					trail.Parent = chairlegs
					table.insert(trails, trail)
				end
				GamingChair:Clean(chair)
				GamingChair:Clean(movingsound)
				GamingChair:Clean(flyingsound)
				chairanim = {Stop = function() end}
				local oldmoving = false
				local oldflying = false
				repeat
					if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
						if not chairanim.IsPlaying then
							local temp2 = Instance.new('Animation')
							temp2.AnimationId = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15 and 'http://www.roblox.com/asset/?id=2506281703' or 'http://www.roblox.com/asset/?id=178130996'
							chairanim = entitylib.character.Humanoid:LoadAnimation(temp2)
							chairanim.Priority = Enum.AnimationPriority.Movement
							chairanim.Looped = true
							chairanim:Play()
						end
						chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
						chairweld.Part1 = entitylib.character.RootPart
						chairlegs.AssemblyLinearVelocity = Vector3.zero
						chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
						chairfan.AssemblyLinearVelocity = Vector3.zero
						chairfan.CFrame = chair.CFrame * CFrame.new(0.047, -1.873, 0) * CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
						local moving = entitylib.character.Humanoid:GetState() == Enum.HumanoidStateType.Running and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
						local flying = vape.Modules.Fly and vape.Modules.Fly.Enabled or vape.Modules.LongJump and vape.Modules.LongJump.Enabled or (vape.Modules.InfiniteFly or {}).Enabled
						if movingsound.TimePosition > 1.9 then
							movingsound.TimePosition = 0.2
						end
						movingsound.PlaybackSpeed = (entitylib.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude / 16
						for _, v in trails do
							v.Enabled = not flying and moving
							v.Color = ColorSequence.new(movingsound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
						end
						if moving ~= oldmoving then
							if movingsound.IsPlaying then
								if not moving then
									movingsound:Stop()
								end
							else
								if not flying and moving then
									movingsound:Play()
								end
							end
							oldmoving = moving
						end
						if flying ~= oldflying then
							if flying then
								if movingsound.IsPlaying then
									movingsound:Stop()
								end
								if not flyingsound.IsPlaying then
									flyingsound:Play()
								end
								if currenttween then
									currenttween:Cancel()
								end
								tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
									Size = Vector3.zero
								})
								tween.Completed:Connect(function(state)
									if state == Enum.PlaybackState.Completed then
										chairfan.Transparency = 0
										chairlegs.Transparency = 1
										tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
											Size = Vector3.new(1.534, 0.328, 1.537) / Vector3.new(791.138, 168.824, 792.027)
										})
										tween:Play()
									end
								end)
								tween:Play()
							else
								if flyingsound.IsPlaying then
									flyingsound:Stop()
								end
								if not movingsound.IsPlaying and moving then
									movingsound:Play()
								end
								if currenttween then currenttween:Cancel() end
								tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
									Size = Vector3.zero
								})
								tween.Completed:Connect(function(state)
									if state == Enum.PlaybackState.Completed then
										chairfan.Transparency = 1
										chairlegs.Transparency = 0
										tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
											Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
										})
										tween:Play()
									end
								end)
								tween:Play()
							end
							oldflying = flying
						end
					else
						chair.Anchored = true
						chairlegs.Anchored = true
						chairfan.Anchored = true
						repeat task.wait() until entitylib.isAlive and entitylib.character.Humanoid.Health > 0
						chair.Anchored = false
						chairlegs.Anchored = false
						chairfan.Anchored = false
						chairanim:Stop()
					end
					task.wait()
				until not GamingChair.Enabled
			else
				if chairanim then
					chairanim:Stop()
				end
			end
		end,
		Tooltip = 'Sit in the best gaming chair known to mankind.'
	})
	
	Color = GamingChair:CreateColorSlider({
		Name = 'Color',
		Function = function(h, s, v)
			if chairhighlight then
				chairhighlight.OutlineColor = Color3.fromHSV(h, s, v)
			end
		end
	})
end)

run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.BackgroundTransparency = 1
				label.Text = '100 ❤️'
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
	
				repeat
					label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health)..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
					task.wait()
				until not Health.Enabled
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)

run(function()
	local MotionBlur
	local Turning
	local Movement
	local Maximum
	local Smoothing
	
	MotionBlur = vape.Categories.Render:CreateModule({
		Name = 'MotionBlur',
		Function = function(callback)
			if callback then
				local blur = Instance.new('BlurEffect')
				blur.Size = 0
				blur.Parent = lightingService
				vape.BlurEffects = vape.BlurEffects or {}
				table.insert(vape.BlurEffects, blur)
				MotionBlur:Clean(blur)
				MotionBlur:Clean(function()
					local index = table.find(vape.BlurEffects, blur)
					if index then
						table.remove(vape.BlurEffects, index)
					end
				end)
	
				local lastlook, lastposition, size = gameCamera.CFrame.LookVector, gameCamera.CFrame.Position, 0
				MotionBlur:Clean(runService.RenderStepped:Connect(function(delta)
					local cframe = gameCamera.CFrame
					local step = math.max(delta, 1 / 240)
					local turn = math.deg(math.acos(math.clamp(cframe.LookVector:Dot(lastlook), -1, 1))) / step
					local travel = (cframe.Position - lastposition).Magnitude / step
					lastlook, lastposition = cframe.LookVector, cframe.Position
	
					local target = math.min((turn * Turning.Value * 0.002) + (travel * Movement.Value * 0.002), Maximum.Value)
					size += (target - size) * math.clamp(step * Smoothing.Value, 0, 1)
					blur.Size = size
				end))
			end
		end,
		Tooltip = 'Blurs the screen based on how fast you are turning and moving.'
	})
	
	Turning = MotionBlur:CreateSlider({
		Name = 'Turn amount',
		Min = 0,
		Max = 10,
		Default = 4,
		Decimal = 10,
		Tooltip = 'How much your camera turning adds to the blur'
	})
	Movement = MotionBlur:CreateSlider({
		Name = 'Movement amount',
		Min = 0,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Tooltip = 'How much your own speed adds to the blur'
	})
	Maximum = MotionBlur:CreateSlider({
		Name = 'Max blur',
		Min = 1,
		Max = 56,
		Default = 14
	})
	Smoothing = MotionBlur:CreateSlider({
		Name = 'Smoothing',
		Min = 1,
		Max = 30,
		Default = 12,
		Tooltip = 'How fast the blur catches up, lower trails behind for longer'
	})
end)

run(function()
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
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontbounds(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace)
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.TextStrokeTransparency = Stroke.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Strings[ent]
			nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.RichText = true
			nametag.Parent = Folder
			Reference[ent] = nametag
		end,
		Drawing = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = {}
			nametag.BG = Drawing.new('Square')
			nametag.BG.Filled = true
			nametag.BG.Transparency = 1 - Background.Value
			nametag.BG.Color = Color3.new()
			nametag.BG.ZIndex = 1
			nametag.Text = Drawing.new('Text')
			nametag.Text.Size = 15 * Scale.Value
			nametag.Text.Font = 0
			nametag.Text.ZIndex = 2
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end
	
			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
			end
	
			nametag.Text.Text = Strings[ent]
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			Reference[ent] = nametag
		end
	}
	
	local Removed = {
		Normal = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, v in v do
					pcall(function()
						v.Visible = false
						v:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local color = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(color.R * 255))..','..tostring(math.floor(color.G * 255))..','..tostring(math.floor(color.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				local size = getfontbounds(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace)
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = Strings[ent]
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end
	
				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end
	
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	}
	
	local ColorFunc = {
		Normal = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.TextColor3 = entitylib.getEntityColor(i) or color
			end
		end,
		Drawing = function(hue, sat, val)
			local color = Color3.fromHSV(hue, sat, val)
			for i, v in Reference do
				v.Text.Color = entitylib.getEntityColor(i) or color
			end
		end
	}
	
	local Loop = {
		Normal = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			for i, v in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						v.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(i.RootPart.Position + Vector3.new(0, i.HipHeight + 1, 0))
				v.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude) or 0
					if Sizes[i] ~= mag then
						v.Text = string.format(Strings[i], mag)
						local ize = getfontbounds(removeTags(v.Text), v.TextSize, v.FontFace)
						v.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
						Sizes[i] = mag
					end
				end
				v.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end,
		Drawing = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
	
			for i, v in Reference do
				if DistanceCheck.Enabled then
					local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude or math.huge
					if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
						v.Text.Visible = false
						v.BG.Visible = false
						continue
					end
				end
	
				local headPos, headVis = gameCamera:WorldToViewportPoint(i.RootPart.Position + Vector3.new(0, i.HipHeight + 1, 0))
				v.Text.Visible = headVis
				v.BG.Visible = headVis
				if not headVis then
					continue
				end
	
				if Distance.Enabled then
					local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude) or 0
					if Sizes[i] ~= mag then
						v.Text.Text = string.format(Strings[i], mag)
						v.BG.Size = Vector2.new(v.Text.TextBounds.X + 8, v.Text.TextBounds.Y + 7)
						Sizes[i] = mag
					end
				end
				v.BG.Position = Vector2.new(headPos.X - (v.BG.Size.X / 2), headPos.Y - v.BG.Size.Y)
				v.Text.Position = v.BG.Position + Vector2.new(4, 3)
			end
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
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
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
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
		Name = 'Transparency',
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
		Name = 'Stroke Transparency',
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
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local PlayerModel
	local Scale
	local Local
	local Mesh
	local Texture
	local Rots = {}
	local models = {}
	
	local function addMesh(ent)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local root = ent.RootPart
		local part = Instance.new('Part')
		part.Size = Vector3.new(3, 3, 3)
		part.CFrame = root.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = workspace
		local meshd = Instance.new('SpecialMesh')
		meshd.MeshId = Mesh.Value
		meshd.TextureId = Texture.Value
		meshd.Scale = Vector3.one * Scale.Value
		meshd.Parent = part
		local weld = Instance.new('WeldConstraint')
		weld.Part0 = part
		weld.Part1 = root
		weld.Parent = part
		models[root] = part
	end
	
	local function removeMesh(ent)
		if models[ent.RootPart] then
			models[ent.RootPart]:Destroy()
			models[ent.RootPart] = nil
		end
	end
	
	PlayerModel = vape.Categories.Render:CreateModule({
		Name = 'PlayerModel',
		Function = function(callback)
			if callback then
				if Local.Enabled then
					PlayerModel:Clean(entitylib.Events.LocalAdded:Connect(addMesh))
					PlayerModel:Clean(entitylib.Events.LocalRemoved:Connect(removeMesh))
					if entitylib.isAlive then
						task.spawn(addMesh, entitylib.character)
					end
				end
				PlayerModel:Clean(entitylib.Events.EntityAdded:Connect(addMesh))
				PlayerModel:Clean(entitylib.Events.EntityRemoved:Connect(removeMesh))
				for _, v in entitylib.List do
					task.spawn(addMesh, v)
				end
			else
				for _, v in models do
					v:Destroy()
				end
				table.clear(models)
			end
		end,
		Tooltip = 'Change the player models to a Mesh'
	})
	
	Scale = PlayerModel:CreateSlider({
		Name = 'Scale',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Function = function(val)
			for _, v in models do
				v.Mesh.Scale = Vector3.one * val
			end
		end,
		Default = 1
	})
	for _, v in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, PlayerModel:CreateSlider({
			Name = v,
			Min = 0,
			Max = 360,
			Function = function(val)
				for i, v in models do
					v.WeldConstraint.Enabled = false
					v.CFrame = i.CFrame * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
					v.WeldConstraint.Enabled = true
				end
			end
		}))
	end
	Local = PlayerModel:CreateToggle({
		Name = 'Local',
		Function = function()
			if PlayerModel.Enabled then
				PlayerModel:Toggle()
				PlayerModel:Toggle()
			end
		end
	})
	Mesh = PlayerModel:CreateTextBox({
		Name = 'Mesh',
		Placeholder = 'mesh id',
		Function = function()
			for _, v in models do
				v.Mesh.MeshId = Mesh.Value
			end
		end
	})
	Texture = PlayerModel:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'texture id',
		Function = function()
			for _, v in models do
				v.Mesh.TextureId = Texture.Value
			end
		end
	})
end)

run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local bkg
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local dot = Instance.new('Frame')
		dot.Size = UDim2.fromOffset(4, 4)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
		dot.Parent = bkg
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
		corner.Parent = dot
		local stroke = Instance.new('UIStroke')
		stroke.Color = Color3.new()
		stroke.Thickness = 1
		stroke.Transparency = 0.8
		stroke.Parent = dot
		Reference[ent] = dot
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			v:Destroy()
		end
	end
	
	Radar = vape:CreateOverlay({
		Name = 'Radar',
		Icon = getvapeasset('kingvape/assets/new/radaricon.png'),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(12, 13),
		Function = function(callback)
			if callback then
				Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					for i, v in Reference do
						v.BackgroundColor3 = entitylib.getEntityColor(i) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
					end
				end))
				Radar:Clean(runService.RenderStepped:Connect(function()
					for i, v in Reference do
						if entitylib.isAlive then
							local dt = CFrame.lookAlong(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(i.RootPart.Position)
							v.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X, Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z)
						end
					end
				end))
			else
				for i in Reference do
					Removed(i)
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
		Name = 'Dot Style',
		List = {'Circles', 'Squares'},
		Function = function(val)
			for _, v in Reference do
				v.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
			end
		end
	})
	PlayerColor = Radar:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			for i, v in Reference do
				v.BackgroundColor3 = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
			end
		end
	})
	bkg = Instance.new('Frame')
	bkg.Size = UDim2.fromOffset(216, 216)
	bkg.Position = UDim2.fromOffset(2, 2)
	bkg.BackgroundColor3 = Color3.new()
	bkg.BackgroundTransparency = 0.5
	bkg.ClipsDescendants = true
	bkg.Parent = Radar.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bkg
	local stroke = Instance.new('UIStroke')
	stroke.Thickness = 2
	stroke.Color = Color3.new()
	stroke.Transparency = 0.4
	stroke.Parent = bkg
	local line1 = Instance.new('Frame')
	line1.Size = UDim2.new(0, 2, 1, 0)
	line1.Position = UDim2.fromScale(0.5, 0.5)
	line1.AnchorPoint = Vector2.new(0.5, 0.5)
	line1.ZIndex = 0
	line1.BackgroundColor3 = Color3.new(1, 1, 1)
	line1.BackgroundTransparency = 0.5
	line1.BorderSizePixel = 0
	line1.Parent = bkg
	local line2 = line1:Clone()
	line2.Size = UDim2.new(1, 0, 0, 2)
	line2.Parent = bkg
	local bar = Instance.new('Frame')
	bar.Size = UDim2.new(1, -6, 0, 4)
	bar.Position = UDim2.fromOffset(3, 0)
	bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
	bar.Parent = bkg
	local barcorner = Instance.new('UICorner')
	barcorner.CornerRadius = UDim.new(0, 8)
	barcorner.Parent = bar
	Radar:CreateColorSlider({
		Name = 'Bar Color',
		Function = function(hue, sat, val)
			bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		end
	})
	Radar:CreateToggle({
		Name = 'Show Background',
		Function = function(callback)
			bkg.BackgroundTransparency = callback and 0.5 or 1
			bar.BackgroundTransparency = callback and 0 or 1
			stroke.Transparency = callback and 0.4 or 1
		end,
		Default = true
	})
	Radar:CreateToggle({
		Name = 'Show Cross',
		Function = function(callback)
			line1.BackgroundTransparency = callback and 0.5 or 1
			line2.BackgroundTransparency = callback and 0.5 or 1
		end,
		Default = true
	})
	Clamp = Radar:CreateToggle({
		Name = 'Clamp Radar',
		Default = true
	})
end)

run(function()
	local Search
	local List
	local Color
	local FillTransparency
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Add(v)
		if not table.find(List.ListEnabled, v.Name) then return end
		if v:IsA('BasePart') or v:IsA('Model') then
			local size = v:IsA('Model') and v:GetExtentsSize() or v.Size
			local box = Instance.new('BoxHandleAdornment')
			box.AlwaysOnTop = true
			box.Adornee = v
			box.Size = size.Magnitude > 0.4 and size or Vector3.one
			box.ZIndex = 0
			box.Transparency = FillTransparency.Value
			box.Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			box.Parent = Folder
			Reference[v] = box
		end
	end
	
	Search = vape.Categories.Render:CreateModule({
		Name = 'Search',
		Function = function(callback)
			if callback then
				Search:Clean(workspace.DescendantAdded:Connect(Add))
				Search:Clean(workspace.DescendantRemoving:Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v] = nil
					end
				end))
	
				for _, v in workspace:GetDescendants() do
					Add(v)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Draws box around selected parts\nAdd parts in Search frame'
	})
	
	List = Search:CreateTextList({
		Name = 'Parts',
		Function = function()
			if Search.Enabled then
				Search:Toggle()
				Search:Toggle()
			end
		end
	})
	Color = Search:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in Reference do
				v.Color3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	FillTransparency = Search:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, v in Reference do
				v.Transparency = val
			end
		end,
		Decimal = 10
	})
end)

run(function()
	local SessionInfo
	local FontOption
	local Hide
	local TextSize
	local BorderColor
	local Title
	local TitleOffset = {}
	local Custom
	local CustomBox
	local infoholder
	local infolabel
	local infostroke
	
	SessionInfo = vape:CreateOverlay({
		Name = 'Session Info',
		Icon = getvapeasset('kingvape/assets/new/textguiicon.png'),
		Size = UDim2.fromOffset(16, 12),
		Position = UDim2.fromOffset(12, 14),
		Function = function(callback)
			if callback then
				local teleportedServers
				SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
					if not teleportedServers then
						teleportedServers = true
						queue_on_teleport("shared.vapesessioninfo = '"..httpService:JSONEncode(vape.Libraries.sessioninfo.Objects).."'")
					end
				end))
	
				if shared.vapesessioninfo then
					for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
						if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
							vape.Libraries.sessioninfo.Objects[i].Value = v.Value
						end
					end
				end
	
				repeat
					if vape.Libraries.sessioninfo then
						local stuff = {''}
						if Title.Enabled then
							stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or '<b>Session Info</b>'
						end
	
						for i, v in vape.Libraries.sessioninfo.Objects do
							stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i..': '..v.Function(v.Value) or false
						end
	
						if #Hide.ListEnabled > 0 then
							local key, val
							repeat
								local oldkey = key
								key, val = next(stuff, key)
								if val == false then
									table.remove(stuff, key)
									key = oldkey
								end
							until not key
						end
	
						if Custom.Enabled then
							table.insert(stuff, CustomBox.Value)
						end
	
						if not Title.Enabled then
							table.remove(stuff, 1)
						end
						infolabel.Text = table.concat(stuff, '\n')
						infolabel.FontFace = FontOption.Value
						infolabel.TextSize = TextSize.Value
						local size = getfontbounds(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
						infoholder.Size = UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
					end
	
					task.wait(1)
				until not SessionInfo.Button or not SessionInfo.Button.Enabled
			end
		end
	})
	
	FontOption = SessionInfo:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial'
	})
	Hide = SessionInfo:CreateTextList({
		Name = 'Blacklist',
		Tooltip = 'Name of entry to hide.',
		Icon = getvapeasset('kingvape/assets/new/blockedicon.png'),
		Tab = getvapeasset('kingvape/assets/new/blockedtab.png'),
		TabSize = UDim2.fromOffset(21, 16),
		Color = Color3.fromRGB(250, 50, 56)
	})
	SessionInfo:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			infoholder.BackgroundTransparency = 1 - opacity
		end
	})
	BorderColor = SessionInfo:CreateColorSlider({
		Name = 'Border Color',
		Function = function(hue, sat, val, opacity)
			infostroke.Color = Color3.fromHSV(hue, sat, val)
			infostroke.Transparency = 1 - opacity
		end,
		Darker = true,
		Visible = false
	})
	TextSize = SessionInfo:CreateSlider({
		Name = 'Text Size',
		Min = 1,
		Max = 30,
		Default = 16
	})
	Title = SessionInfo:CreateToggle({
		Name = 'Title',
		Function = function(callback)
			if TitleOffset.Object then
				TitleOffset.Object.Visible = callback
			end
		end,
		Default = true
	})
	TitleOffset = SessionInfo:CreateToggle({
		Name = 'Offset',
		Default = true,
		Darker = true
	})
	SessionInfo:CreateToggle({
		Name = 'Border',
		Function = function(callback)
			infostroke.Enabled = callback
			BorderColor.Object.Visible = callback
		end
	})
	Custom = SessionInfo:CreateToggle({
		Name = 'Add custom text',
		Function = function(enabled)
			CustomBox.Object.Visible = enabled
		end
	})
	CustomBox = SessionInfo:CreateTextBox({
		Name = 'Custom text',
		Darker = true,
		Visible = false
	})
	infoholder = Instance.new('Frame')
	infoholder.BackgroundColor3 = Color3.new()
	infoholder.BackgroundTransparency = 0.5
	infoholder.Parent = SessionInfo.Children
	vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
		infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
	end))
	local sessioninfocorner = Instance.new('UICorner')
	sessioninfocorner.CornerRadius = UDim.new(0, 5)
	sessioninfocorner.Parent = infoholder
	infolabel = Instance.new('TextLabel')
	infolabel.Size = UDim2.new(1, -16, 1, -16)
	infolabel.Position = UDim2.fromOffset(8, 8)
	infolabel.BackgroundTransparency = 1
	infolabel.TextXAlignment = Enum.TextXAlignment.Left
	infolabel.TextYAlignment = Enum.TextYAlignment.Top
	infolabel.TextSize = 16
	infolabel.TextColor3 = Color3.new(1, 1, 1)
	infolabel.TextStrokeColor3 = Color3.new()
	infolabel.TextStrokeTransparency = 0.8
	infolabel.Font = Enum.Font.Arial
	infolabel.RichText = true
	infolabel.Parent = infoholder
	infostroke = Instance.new('UIStroke')
	infostroke.Enabled = false
	infostroke.Color = Color3.fromHSV(0.44, 1, 1)
	infostroke.Parent = infoholder
	addBlur(infoholder)
	vape.Libraries.sessioninfo = {
		Objects = {},
		AddItem = function(self, name, startvalue, func, saved)
			func, saved = func or function(val) return val end, saved == nil or saved
			self.Objects[name] = {Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2}
			return {
				Increment = function(_, val)
					self.Objects[name].Value += (val or 1)
				end,
				Get = function()
					return self.Objects[name].Value
				end
			}
		end
	}
	vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
		return os.date('!%X', math.floor(os.clock() - value))
	end)
end)

run(function()
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
	
	local function Added(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local EntityTracer = Drawing.new('Line')
		EntityTracer.Thickness = 1
		EntityTracer.Transparency = 1 - Transparency.Value
		EntityTracer.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		Reference[ent] = EntityTracer
	end
	
	local function Removed(ent)
		local v = Reference[ent]
		if v then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[ent] = nil
			pcall(function()
				v.Visible = false
				v:Remove()
			end)
		end
	end
	
	local function ColorFunc(hue, sat, val)
		if DistanceColor.Enabled then return end
		local tracerColor = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Color = entitylib.getEntityColor(i) or tracerColor
		end
	end
	
	local function Loop()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local screenSize = vape.gui.AbsoluteSize
		local startVector = StartPosition.Value == 'Mouse' and inputService:GetMouseLocation() or Vector2.new(screenSize.X / 2, (StartPosition.Value == 'Middle' and screenSize.Y / 2 or screenSize.Y))
	
		for i, v in Reference do
			local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - i.RootPart.Position).Magnitude
			if Distance.Enabled and distance then
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					v.Visible = false
					continue
				end
			end
	
			local pos = i[EndPosition.Value == 'Torso' and 'RootPart' or 'Head'].Position
			local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos)
			if not rootVis and Behind.Enabled then
				local tempPos = gameCamera.CFrame:PointToObjectSpace(pos)
				tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
				rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
				rootVis = true
			end
	
			local endVector = Vector2.new(rootPos.X, rootPos.Y)
			v.Visible = rootVis
			v.From = startVector
			v.To = endVector
			if DistanceColor.Enabled and distance then
				v.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
			end
		end
	end
	
	Tracers = vape.Categories.Render:CreateModule({
		Name = 'Tracers',
		Function = function(callback)
			if callback then
				Tracers:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
				for _, v in entitylib.List do
					if Reference[v] then
						Removed(v)
					end
					Added(v)
				end
				Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed(ent)
					end
					Added(ent)
				end))
				Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc(Color.Hue, Color.Sat, Color.Value)
				end))
				Tracers:Clean(runService.RenderStepped:Connect(Loop))
			else
				for i in Reference do
					Removed(i)
				end
			end
		end,
		Tooltip = 'Renders tracers on players.'
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
		Name = 'Start Position',
		List = {'Middle', 'Bottom', 'Mouse'},
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	EndPosition = Tracers:CreateDropdown({
		Name = 'End Position',
		List = {'Head', 'Torso'},
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	Color = Tracers:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if Tracers.Enabled then
				ColorFunc(hue, sat, val)
			end
		end
	})
	Transparency = Tracers:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Function = function(val)
			for _, v in Reference do
				v.Transparency = 1 - val
			end
		end,
		Decimal = 10
	})
	DistanceColor = Tracers:CreateToggle({
		Name = 'Color by distance',
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end
	})
	Distance = Tracers:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = Tracers:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
	Behind = Tracers:CreateToggle({
		Name = 'Behind',
		Default = true
	})
	Teammates = Tracers:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if Tracers.Enabled then
				Tracers:Toggle()
				Tracers:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides teammates & non targetable entities'
	})
end)

run(function()
	local Waypoints
	local FontOption
	local List
	local Color
	local Scale
	local Background
	WaypointFolder = Instance.new('Folder')
	WaypointFolder.Parent = vape.gui
	
	Waypoints = vape.Categories.Render:CreateModule({
		Name = 'Waypoints',
		Function = function(callback)
			if callback then
				for _, v in List.ListEnabled do
					local split = v:split('/')
					local tagSize = getfontbounds(removeTags(split[2]), 14 * Scale.Value, FontOption.Value)
					local billboard = Instance.new('BillboardGui')
					billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
					billboard.StudsOffsetWorldSpace = Vector3.new(unpack(split[1]:split(',')))
					billboard.AlwaysOnTop = true
					billboard.Parent = WaypointFolder
					local tag = Instance.new('TextLabel')
					tag.BackgroundColor3 = Color3.new()
					tag.BorderSizePixel = 0
					tag.Visible = true
					tag.RichText = true
					tag.FontFace = FontOption.Value
					tag.TextSize = 14 * Scale.Value
					tag.BackgroundTransparency = Background.Value
					tag.Size = billboard.Size
					tag.Text = split[2]
					tag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					tag.Parent = billboard
				end
			else
				WaypointFolder:ClearAllChildren()
			end
		end,
		Tooltip = 'Mark certain spots with a visual indicator'
	})
	
	FontOption = Waypoints:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end
	})
	List = Waypoints:CreateTextList({
		Name = 'Points',
		Placeholder = 'x, y, z/name',
		Function = function()
			if Waypoints.Enabled then
				Waypoints:Toggle()
				Waypoints:Toggle()
			end
		end
	})
	Waypoints:CreateButton({
		Name = 'Add current position',
		Function = function()
			if entitylib.isAlive then
				local pos = entitylib.character.RootPart.Position // 1
				List:ChangeValue(pos.X..','..pos.Y..','..pos.Z..'/Waypoint '..(#List.List + 1))
			end
		end
	})
	Color = Waypoints:CreateColorSlider({
		Name = 'Color',
		Function = function(hue, sat, val)
			for _, v in WaypointFolder:GetChildren() do
				v.TextLabel.TextColor3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Scale = Waypoints:CreateSlider({
		Name = 'Scale',
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
		Name = 'Transparency',
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

run(function()
	local ZoomUnlocker
	local Distance
	local FirstPerson
	local oldmax, oldmin
	
	ZoomUnlocker = vape.Categories.Render:CreateModule({
		Name = 'ZoomUnlocker',
		Function = function(callback)
			if callback then
				oldmax, oldmin = lplr.CameraMaxZoomDistance, lplr.CameraMinZoomDistance
				repeat
					local min = FirstPerson.Enabled and 0.5 or math.min(oldmin, Distance.Value)
					if lplr.CameraMinZoomDistance ~= min or lplr.CameraMaxZoomDistance ~= Distance.Value then
						lplr.CameraMinZoomDistance = min
						lplr.CameraMaxZoomDistance = Distance.Value
					end
					task.wait()
				until not ZoomUnlocker.Enabled
			else
				lplr.CameraMinZoomDistance = oldmin
				lplr.CameraMaxZoomDistance = oldmax
			end
		end,
		Tooltip = 'Removes the zoom limit the game puts on your camera'
	})
	
	Distance = ZoomUnlocker:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 500,
		Default = 128,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	FirstPerson = ZoomUnlocker:CreateToggle({
		Name = 'Allow first person',
		Default = true,
		Tooltip = 'Also unlocks zooming all the way in'
	})
end)

run(function()
	local AnimationPlayer
	local IDBox
	local Priority
	local Speed
	local anim, animobject
	
	local function playAnimation(char)
		local animcheck = anim
		if animcheck then
			anim = nil
			animcheck:Stop()
		end
	
		local suc, res = pcall(function()
			anim = char.Humanoid.Animator:LoadAnimation(animobject)
		end)
	
		if suc then
			local currentanim = anim
			anim.Priority = Enum.AnimationPriority[Priority.Value]
			anim:Play()
			anim:AdjustSpeed(Speed.Value)
			AnimationPlayer:Clean(anim.Stopped:Connect(function()
				if currentanim == anim then
					anim:Play()
				end
			end))
		else
			notif('AnimationPlayer', 'failed to load anim : '..(res or 'invalid animation id'), 5, 'warning')
		end
	end
	
	AnimationPlayer = vape.Categories.Utility:CreateModule({
		Name = 'AnimationPlayer',
		Function = function(callback)
			if callback then
				animobject = Instance.new('Animation')
				local suc, id = pcall(function()
					return string.match(game:GetObjects('rbxassetid://'..IDBox.Value)[1].AnimationId, '%?id=(%d+)')
				end)
				animobject.AnimationId = 'rbxassetid://'..(suc and id or IDBox.Value)
	
				if entitylib.isAlive then
					playAnimation(entitylib.character)
				end
				AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
				AnimationPlayer:Clean(animobject)
			else
				if anim then
					anim:Stop()
				end
			end
		end,
		Tooltip = 'Plays a specific animation of your choosing at a certain speed'
	})
	
	IDBox = AnimationPlayer:CreateTextBox({
		Name = 'Animation',
		Placeholder = 'anim (num only)',
		Function = function(enter)
			if enter and AnimationPlayer.Enabled then
				AnimationPlayer:Toggle()
				AnimationPlayer:Toggle()
			end
		end
	})
	local prio = {'Action4'}
	for _, v in Enum.AnimationPriority:GetEnumItems() do
		if v.Name ~= 'Action4' then
			table.insert(prio, v.Name)
		end
	end
	Priority = AnimationPlayer:CreateDropdown({
		Name = 'Priority',
		List = prio,
		Function = function(val)
			if anim then
				anim.Priority = Enum.AnimationPriority[val]
			end
		end
	})
	Speed = AnimationPlayer:CreateSlider({
		Name = 'Speed',
		Function = function(val)
			if anim then
				anim:AdjustSpeed(val)
			end
		end,
		Min = 0.1,
		Max = 2,
		Decimal = 10
	})
end)

run(function()
	local AntiRagdoll
	
	AntiRagdoll = vape.Categories.Utility:CreateModule({
		Name = 'AntiRagdoll',
		Function = function(callback)
			if entitylib.isAlive then
				entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not callback)
			end
	
			if callback then
				AntiRagdoll:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
				end))
			end
		end,
		Tooltip = 'Prevents you from getting knocked down in a ragdoll state'
	})
end)

run(function()
	local AutoRejoin
	local Sort
	
	AutoRejoin = vape.Categories.Utility:CreateModule({
		Name = 'AutoRejoin',
		Function = function(callback)
			if callback then
				local check
				AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
					if (not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not str:lower():find('ban') then
						check = true
						serverHop(nil, Sort.Value)
					end
				end))
			end
		end,
		Tooltip = 'Automatically rejoins into a new server if you get disconnected / kicked'
	})
	
	Sort = AutoRejoin:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
end)

run(function()
	local Blink
	local Type
	local AutoSend
	local AutoSendLength
	local oldphys, oldsend
	
	Blink = vape.Categories.Utility:CreateModule({
		Name = 'Blink',
		Function = function(callback)
			if callback then
				local teleported
				Blink:Clean(lplr.OnTeleport:Connect(function()
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
					teleported = true
				end))
	
				repeat
					local physicsrate, senderrate = '0', Type.Value == 'All' and '-1' or '60'
					if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
						physicsrate, senderrate = '38760', '60'
					end
	
					if physicsrate ~= oldphys or senderrate ~= oldsend then
						setfflag('PhysicsSenderMaxBandwidthBps', physicsrate)
						setfflag('DataSenderRate', senderrate)
						oldphys, oldsend = physicsrate, senderrate
					end
	
					task.wait(0.03)
				until (not Blink.Enabled and not teleported)
			else
				if setfflag then
					setfflag('PhysicsSenderMaxBandwidthBps', '38760')
					setfflag('DataSenderRate', '60')
				end
				oldphys, oldsend = nil, nil
			end
		end,
		Tooltip = 'Chokes packets until disabled.'
	})
	
	Type = Blink:CreateDropdown({
		Name = 'Type',
		List = {'Movement Only', 'All'},
		Tooltip = 'Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement'
	})
	AutoSend = Blink:CreateToggle({
		Name = 'Auto send',
		Function = function(callback)
			AutoSendLength.Object.Visible = callback
		end,
		Tooltip = 'Automatically send packets in intervals'
	})
	AutoSendLength = Blink:CreateSlider({
		Name = 'Send threshold',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
end)

run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local RandomList = {}
	local oldchat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
		Name = 'ChatSpammer',
		Function = function(callback)
			if callback then
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
						ChatSpammer:Clean(coreGui.ExperienceChat.appLayout.chatWindow.contentFrame.scrollingView.bottomLockedScrollView.scrollView.ChildAdded:Connect(function(msg)
							if msg.Name:sub(1, 2) == '0-' and msg.TextMessage.BodyText.Text == '<font color="#d4d4d4">You must wait before sending another message.</font>' then
								msg.Visible = false
							end
						end))
					end
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					if Hide.Enabled then
						oldchat = hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(data, ...)
							if data.Message:find('ChatFloodDetector') then return end
							return oldchat(data, ...)
						end)
					end
				else
					notif('ChatSpammer', 'unsupported chat', 5, 'warning')
					ChatSpammer:Toggle()
					return
				end
	
				local index = 1
				repeat
					local message = 'vxpe on top'
					if #Lines.ListEnabled > 0 then
						if Mode.Value == 'Order' then
							message = Lines.ListEnabled[index] or Lines.ListEnabled[1]
							index = (index % #Lines.ListEnabled) + 1
						else
							if #RandomList <= 0 then
								RandomList = table.clone(Lines.ListEnabled)
							end
	
							local entry = Random.new():NextInteger(1, #RandomList)
							message = RandomList[entry]
							table.remove(RandomList, entry)
						end
					end
	
					if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
						textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
					else
						replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
					end
	
					task.wait(Delay.Value)
				until not ChatSpammer.Enabled
			else
				if oldchat then
					hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, oldchat)
				end
			end
		end,
		Tooltip = 'Automatically types in chat'
	})
	
	Lines = ChatSpammer:CreateTextList({
		Name = 'Lines',
		Function = function()
			table.clear(RandomList)
		end
	})
	Mode = ChatSpammer:CreateDropdown({
		Name = 'Mode',
		List = {'Random', 'Order'}
	})
	Delay = ChatSpammer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Hide = ChatSpammer:CreateToggle({
		Name = 'Hide Flood Message',
		Function = function()
			if ChatSpammer.Enabled then
				ChatSpammer:Toggle()
				ChatSpammer:Toggle()
			end
		end,
		Default = true
	})
end)

run(function()
	local Disabler
	
	local function characterAdded(char)
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('CFrame')) do
			hookfunction(v.Function, function() end)
		end
	
		for _, v in getconnections(char.RootPart:GetPropertyChangedSignal('Velocity')) do
			hookfunction(v.Function, function() end)
		end
	end
	
	Disabler = vape.Categories.Utility:CreateModule({
		Name = 'Disabler',
		Function = function(callback)
			if callback then
				Disabler:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
				if entitylib.isAlive then
					characterAdded(entitylib.character)
				end
			end
		end,
		Tooltip = 'Disables GetPropertyChangedSignal detections for movement'
	})
end)

run(function()
	local time = tick()
	local Panic; Panic = vape.Categories.Utility:CreateModule({
		Name = 'Panic',
		Function = function(callback)
			if callback then
				if time > tick() then
					for _, v in vape.Modules do
						if v.Enabled then
							v:Toggle()
						end
					end
				else
					notif('Panic', 'Re-enable panic to confirm', 5, 'info')
					time = tick() + 1
					Panic:Toggle()
				end
			end
		end,
		Tooltip = 'Disables all currently enabled modules'
	})
end)

run(function()
	local Rejoin
	
	Rejoin = vape.Categories.Utility:CreateModule({
		Name = 'Rejoin',
		Function = function(callback)
			if callback then
				notif('Rejoin', 'Rejoining...', 5)
				Rejoin:Toggle()
	
				if playersService.NumPlayers > 1 then
					teleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
				else
					teleportService:Teleport(game.PlaceId)
				end
			end
		end,
		Tooltip = 'Rejoins the server'
	})
end)

run(function()
	local ServerHop
	local Sort
	
	ServerHop = vape.Categories.Utility:CreateModule({
		Name = 'ServerHop',
		Function = function(callback)
			if callback then
				ServerHop:Toggle()
				serverHop(nil, Sort.Value)
			end
		end,
		Tooltip = 'Teleports into a unique server'
	})
	
	Sort = ServerHop:CreateDropdown({
		Name = 'Sort',
		List = {'Descending', 'Ascending'},
		Tooltip = 'Descending - Prefers full servers\nAscending - Prefers empty servers'
	})
	ServerHop:CreateButton({
		Name = 'Rejoin Previous Server',
		Function = function()
			notif('ServerHop', shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server', 5)
			if shared.vapeserverhopprevious then
				teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
			end
		end
	})
end)

run(function()
	local StaffDetector
	local Mode
	local Profile
	local Users
	local Group
	local Role
	
	local function playerAdded(plr)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		local user = table.find(Users.ListEnabled, tostring(plr.UserId))
		local suc, rank
		if not user then
			for _ = 1, 3 do
				suc, rank = pcall(function()
					return plr:GetRankInGroup(tonumber(Group.Value) or 0)
				end)
				if suc then break end
			end
		end
	
		if user or (suc and rank or 0) >= (tonumber(Role.Value) or 1) then
			notif('StaffDetector', 'Staff Detected ('..(user and 'blacklisted_user' or 'staff_role')..'): '..plr.Name, 60, 'alert')
			whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
			if Mode.Value == 'Uninject' then
				task.spawn(function()
					vape:Uninject()
				end)
				game:GetService('StarterGui'):SetCore('SendNotification', {
					Title = 'StaffDetector',
					Text = 'Staff Detected\n'..plr.Name,
					Duration = 60,
				})
			elseif Mode.Value == 'ServerHop' then
				serverHop()
			elseif Mode.Value == 'Profile' then
				vape.Save = function() end
				if vape.Profile ~= Profile.Value then
					vape.Profile = Profile.Value
					vape:Load(true, Profile.Value)
				end
			elseif Mode.Value == 'AutoConfig' then
				vape.Save = function() end
				for _, v in vape.Modules do
					if v.Enabled then
						v:Toggle()
					end
				end
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				if Group.Value == '' or Role.Value == '' then
					local placeinfo = {Creator = {CreatorTargetId = tonumber(Group.Value)}}
					if Group.Value == '' then
						placeinfo = marketplaceService:GetProductInfo(game.PlaceId)
						if placeinfo.Creator.CreatorType ~= 'Group' then
							local desc = placeinfo.Description:split('\n')
							for _, v in desc do
								local _, begin = v:find('roblox.com/groups/')
								if begin then
									local endof = v:find('/', begin + 1)
									placeinfo = {Creator = {
										CreatorType = 'Group',
										CreatorTargetId = v:sub(begin + 1, endof - 1)
									}}
								end
							end
						end
	
						if placeinfo.Creator.CreatorType ~= 'Group' then
							notif('StaffDetector', 'Automatic Setup Failed (no group detected)', 60, 'warning')
							return
						end
					end
	
					local groupinfo = groupService:GetGroupInfoAsync(placeinfo.Creator.CreatorTargetId)
					Group:SetValue(placeinfo.Creator.CreatorTargetId)
					local highest = math.huge
					for _, v in groupinfo.Roles do
						local low = v.Name:lower()
						if (low:find('admin') or low:find('mod') or low:find('dev')) and v.Rank < highest then
							highest = v.Rank
						end
					end
	
					Role:SetValue(highest)
				end
	
				if Group.Value == '' or Role.Value == '' then
					return
				end
	
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'ServerHop', 'Profile', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	Group = StaffDetector:CreateTextBox({
		Name = 'Group',
		Placeholder = 'Group Id'
	})
	Role = StaffDetector:CreateTextBox({
		Name = 'Role',
		Placeholder = 'Role Rank'
	})
end)

run(function()
	local connections = {}
	
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					table.insert(connections, v)
					v:Disable()
				end
			else
				for _, v in connections do
					v:Enable()
				end
				table.clear(connections)
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)

run(function()
	local Freecam
	local Value
	local randomkey, module, old = httpService:GenerateGUID(false)
	local controls, touchUp = nil, 0
	
	Freecam = vape.Categories.World:CreateModule({
		Name = 'Freecam',
		Function = function(callback)
			if callback then
				repeat
					task.wait(0.1)
					for _, v in getconnections(gameCamera:GetPropertyChangedSignal('CameraType')) do
						if v.Function then
							module = debug.getupvalue(v.Function, 1)
						end
					end
				until module or not Freecam.Enabled
	
				if module and module.activeCameraController and Freecam.Enabled then
					old = module.activeCameraController.GetSubjectPosition
					local camPos = old(module.activeCameraController) or Vector3.zero
					module.activeCameraController.GetSubjectPosition = function()
						return camPos
					end
	
					Freecam:Clean(runService.PreSimulation:Connect(function(dt)
						if not inputService:GetFocusedTextBox() then
							if not controls then
								local loaded, result = pcall(function()
									return require(lplr.PlayerScripts:WaitForChild('PlayerModule', 5)):GetControls()
								end)
								controls = loaded and result or nil
							end
	
							local moved, vector = pcall(function()
								return controls:GetMoveVector()
							end)
							local moveVector = moved and vector or Vector3.zero
							local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) + moveVector.Z
							local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) + moveVector.X
							local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0) + touchUp
							dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
							camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
						end
					end))
	
					if inputService.TouchEnabled then
						pcall(function()
							local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
							Freecam:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
								touchUp = jumpButton.ImageRectOffset.X == 146 and 1 or 0
							end))
						end)
					end
	
					contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
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
				touchUp = 0
				pcall(function()
					contextService:UnbindAction('FreecamKeyboard'..randomkey)
				end)
				if module and old then
					module.activeCameraController.GetSubjectPosition = old
					module = nil
					old = nil
				end
			end
		end,
		Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
	})
	
	Value = Freecam:CreateSlider({
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
	local Gravity
	local Mode
	local Value
	local changed, old = false
	
	Gravity = vape.Categories.World:CreateModule({
		Name = 'Gravity',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Workspace' then
					old = workspace.Gravity
					workspace.Gravity = Value.Value
					Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
						if changed then return end
						changed = true
						old = workspace.Gravity
						workspace.Gravity = Value.Value
						changed = false
					end))
				else
					Gravity:Clean(runService.PreSimulation:Connect(function(dt)
						if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
							local root = entitylib.character.RootPart
							if Mode.Value == 'Impulse' then
								root:ApplyImpulse(Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass)
							else
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
							end
						end
					end))
				end
			else
				if old then
					workspace.Gravity = old
					old = nil
				end
			end
		end,
		Tooltip = 'Changes the rate you fall'
	})
	
	Mode = Gravity:CreateDropdown({
		Name = 'Mode',
		List = {'Workspace', 'Velocity', 'Impulse'},
		Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
	})
	Value = Gravity:CreateSlider({
		Name = 'Gravity',
		Min = 0,
		Max = 192,
		Function = function(val)
			if Gravity.Enabled and Mode.Value == 'Workspace' then
				changed = true
				workspace.Gravity = val
				changed = false
			end
		end,
		Default = 192
	})
end)

run(function()
	local Parkour
	
	Parkour = vape.Categories.World:CreateModule({
		Name = 'Parkour',
		Function = function(callback)
			if callback then
				local oldfloor
				Parkour:Clean(runService.RenderStepped:Connect(function()
					if entitylib.isAlive then
						local material = entitylib.character.Humanoid.FloorMaterial
						if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then
							entitylib.character.Humanoid.Jump = true
						end
						oldfloor = material
					end
				end))
			end
		end,
		Tooltip = 'Automatically jumps after reaching the edge'
	})
end)

run(function()
	local PromptChanger
	local Mode
	local Distance
	local Hold
	local Sight
	local modified = setmetatable({}, {__mode = 'k'})
	local thread
	
	local function changePrompt(prompt)
		if not prompt:IsA('ProximityPrompt') then return end
	
		if not modified[prompt] then
			modified[prompt] = {Distance = prompt.MaxActivationDistance, Hold = prompt.HoldDuration, Sight = prompt.RequiresLineOfSight}
		end
	
		prompt.MaxActivationDistance = Distance.Value
		prompt.RequiresLineOfSight = not Sight.Enabled
	
		if Mode.Value == 'Property' then
			prompt.HoldDuration = modified[prompt].Hold * (Hold.Value / 100)
		end
	end
	
	PromptChanger = vape.Categories.World:CreateModule({
		Name = 'PromptChanger',
		Function = function(callback)
			if callback then
				PromptChanger:Clean(workspace.DescendantAdded:Connect(changePrompt))
				for _, v in workspace:GetDescendants() do
					changePrompt(v)
				end
	
				if Mode.Value == 'Signal' then
					PromptChanger:Clean(proxService.PromptButtonHoldBegan:Connect(function(prompt, plr)
						if plr == lplr then
							thread = task.delay(prompt.HoldDuration * (Hold.Value / 100), function()
								fireproximityprompt(prompt)
								thread = nil
							end)
						end
					end))
	
					PromptChanger:Clean(proxService.PromptButtonHoldEnded:Connect(function(prompt, plr)
						if plr == lplr and thread then
							task.cancel(thread)
							thread = nil
						end
					end))
				end
			else
				if thread then
					task.cancel(thread)
					thread = nil
				end
	
				for i, v in modified do
					i.MaxActivationDistance = v.Distance
					i.HoldDuration = v.Hold
					i.RequiresLineOfSight = v.Sight
				end
	
				table.clear(modified)
			end
		end,
		Tooltip = 'Lets you use proximity prompts from further away and hold them for less time'
	})
	
	Mode = PromptChanger:CreateDropdown({
		Name = 'Mode',
		List = {'Property', 'Signal'},
		Function = function()
			if PromptChanger.Enabled then
				PromptChanger:Toggle()
				PromptChanger:Toggle()
			end
		end,
		Tooltip = 'Property - Writes the hold time onto every prompt\nSignal - Leaves the prompt alone and fires it early instead'
	})
	Distance = PromptChanger:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 500,
		Function = function(val)
			for i in modified do
				i.MaxActivationDistance = val
			end
		end,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end,
		Default = 50
	})
	Hold = PromptChanger:CreateSlider({
		Name = 'Hold time',
		Min = 0,
		Max = 100,
		Function = function(val)
			if Mode.Value == 'Property' then
				for i, v in modified do
					i.HoldDuration = v.Hold * (val / 100)
				end
			end
		end,
		Suffix = '%',
		Default = 0,
		Tooltip = 'How much of the original hold time you still have to wait'
	})
	Sight = PromptChanger:CreateToggle({
		Name = 'Through walls',
		Function = function(callback)
			for i in modified do
				i.RequiresLineOfSight = not callback
			end
		end,
		Tooltip = 'Also removes the line of sight requirement'
	})
end)

run(function()
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	vape.Categories.World:CreateModule({
		Name = 'SafeWalk',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function()
						module = require(lplr.PlayerScripts.PlayerModule).controls
					end)
					if not suc then module = {} end
				end
	
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = 'Prevents you from walking off the edge of parts'
	})
end)

run(function()
	local Wallhop
	local Offset
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	local oldvec
	local timeout = os.clock()
	local set
	
	local function doCheck()
		if set then
			gameCamera.CFrame = CFrame.new(gameCamera.CFrame.Position.X, gameCamera.CFrame.Position.Y, gameCamera.CFrame.Position.Z, unpack(set, 4, set.n))
			set = nil
		end
	
		local hum = entitylib.isAlive and entitylib.character.Humanoid
		if hum and hum.Jump and hum.MoveDirection.Magnitude > 0 then
			local root = entitylib.character.RootPart
			params.CollisionGroup = root.CollisionGroup
			params.FilterDescendantsInstances = {lplr.Character}
	
			if root.AssemblyLinearVelocity.Y < 0 and hum.FloorMaterial == Enum.Material.Air then
				local feet = root.Position
				local parts = workspace:GetPartBoundsInBox(CFrame.new(root.Position - Vector3.new(0, entitylib.character.HipHeight / 2, 0)), Vector3.new(3, entitylib.character.HipHeight, 3), params)
				local doHop = false
	
				for _, v in parts do
					local pos = v:GetClosestPointOnSurface(root.Position)
					local diff = (root.Position.Y - pos.Y)
					if diff > root.Size.Y / 2 then
						doHop = true
						break
					end
				end
	
				if doHop and (os.clock() - timeout) > 0.2 then
					set = table.pack(gameCamera.CFrame:GetComponents())
					gameCamera.CFrame *= CFrame.Angles(0, math.rad(Offset.Value), 0)
					timeout = os.clock()
				end
			end
		end
	end
	
	Wallhop = vape.Categories.World:CreateModule({
		Name = 'Wallhop',
		Function = function(callback)
			if callback then
				if workspace.AuthorityMode == Enum.AuthorityMode.Server then
					Wallhop:Clean(runService:BindToSimulation(doCheck))
				else
					Wallhop:Clean(runService.RenderStepped:Connect(doCheck))
				end
			else
				set = nil
			end
		end,
		Tooltip = 'Automatically rotates camera for wallhopping.'
	})
	
	Offset = Wallhop:CreateSlider({
		Name = 'Offset',
		Min = -45,
		Max = 45,
		Default = 45,
		Suffix = 'degrees'
	})
end)

run(function()
	local Xray
	local List
	local modified = {}
	
	local function modifyPart(v)
		if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
			modified[v] = true
			v.LocalTransparencyModifier = 0.5
		end
	end
	
	Xray = vape.Categories.World:CreateModule({
		Name = 'Xray',
		Function = function(callback)
			if callback then
				Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
				for _, v in workspace:GetDescendants() do
					modifyPart(v)
				end
			else
				for i in modified do
					i.LocalTransparencyModifier = 0
				end
				table.clear(modified)
			end
		end,
		Tooltip = 'Renders whitelisted parts through walls.'
	})
	
	List = Xray:CreateTextList({
		Name = 'Part',
		Function = function()
			if Xray.Enabled then
				Xray:Toggle()
				Xray:Toggle()
			end
		end
	})
end)

run(function()
	local Atmosphere
	local Toggles = {}
	local newobjects, oldobjects = {}, {}
	local apidump = {
		Sky = {
			SkyboxUp = 'Text',
			SkyboxDn = 'Text',
			SkyboxLf = 'Text',
			SkyboxRt = 'Text',
			SkyboxFt = 'Text',
			SkyboxBk = 'Text',
			SunTextureId = 'Text',
			SunAngularSize = 'Number',
			MoonTextureId = 'Text',
			MoonAngularSize = 'Number',
			StarCount = 'Number'
		},
		Atmosphere = {
			Color = 'Color',
			Decay = 'Color',
			Density = 'Number',
			Offset = 'Number',
			Glare = 'Number',
			Haze = 'Number'
		},
		BloomEffect = {
			Intensity = 'Number',
			Size = 'Number',
			Threshold = 'Number'
		},
		DepthOfFieldEffect = {
			FarIntensity = 'Number',
			FocusDistance = 'Number',
			InFocusRadius = 'Number',
			NearIntensity = 'Number'
		},
		SunRaysEffect = {
			Intensity = 'Number',
			Spread = 'Number'
		},
		ColorCorrectionEffect = {
			TintColor = 'Color',
			Saturation = 'Number',
			Contrast = 'Number',
			Brightness = 'Number'
		}
	}
	
	local function removeObject(v)
		if not table.find(newobjects, v) then
			local toggle = Toggles[v.ClassName]
			if toggle and toggle.Toggle.Enabled then
				if v.Parent then
					table.insert(oldobjects, v)
					v.Parent = game
				end
			end
		end
	end
	
	Atmosphere = vape.Legit:CreateModule({
		Name = 'Atmosphere',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_atmosphere.png'),
		Function = function(callback)
			if callback then
				for _, v in lightingService:GetChildren() do
					removeObject(v)
				end
	
				Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
					task.defer(removeObject, v)
				end))
	
				for i, v in Toggles do
					if v.Toggle.Enabled then
						local obj = Instance.new(i)
						for i2, v2 in v.Objects do
							if v2.Type == 'ColorSlider' then
								obj[i2] = Color3.fromHSV(v2.Hue, v2.Sat, v2.Value)
							else
								obj[i2] = apidump[i][i2] ~= 'Number' and v2.Value or tonumber(v2.Value) or 0
							end
						end
						obj.Parent = lightingService
						table.insert(newobjects, obj)
					end
				end
			else
				for _, v in newobjects do
					v:Destroy()
				end
	
				for _, v in oldobjects do
					v.Parent = lightingService
				end
	
				table.clear(newobjects)
				table.clear(oldobjects)
			end
		end,
		Tooltip = 'Custom lighting objects'
	})
	
	for i, v in apidump do
		Toggles[i] = {Objects = {}}
		Toggles[i].Toggle = Atmosphere:CreateToggle({
			Name = i,
			Function = function(callback)
				if Atmosphere.Enabled then
					Atmosphere:Toggle()
					Atmosphere:Toggle()
				end
	
				for _, v in Toggles[i].Objects do
					v.Object.Visible = callback
				end
			end
		})
	
		for i2, v2 in v do
			if v2 == 'Text' or v2 == 'Number' then
				Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
					Name = i2,
					Function = function(enter)
						if Atmosphere.Enabled and enter then
							Atmosphere:Toggle()
							Atmosphere:Toggle()
						end
					end,
					Darker = true,
					Default = v2 == 'Number' and '0' or nil,
					Visible = false
				})
			elseif v2 == 'Color' then
				Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
					Name = i2,
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

run(function()
	local Breadcrumbs
	local Texture
	local Lifetime
	local Thickness
	local FadeIn
	local FadeOut
	local trail, point, point2
	
	Breadcrumbs = vape.Legit:CreateModule({
		Name = 'Breadcrumbs',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_breadcrumbs.png'),
		Function = function(callback)
			if callback then
				point = Instance.new('Attachment')
				point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
				point2 = Instance.new('Attachment')
				point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
				trail = Instance.new('Trail')
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
				trail.TextureMode = Enum.TextureMode.Static
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
				trail.Lifetime = Lifetime.Value
				trail.Attachment0 = point
				trail.Attachment1 = point2
				trail.FaceCamera = true
	
				Breadcrumbs:Clean(trail)
				Breadcrumbs:Clean(point)
				Breadcrumbs:Clean(point2)
				Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					point.Parent = ent.HumanoidRootPart
					point2.Parent = ent.HumanoidRootPart
					trail.Parent = gameCamera
				end))
	
				if entitylib.isAlive then
					point.Parent = entitylib.character.RootPart
					point2.Parent = entitylib.character.RootPart
					trail.Parent = gameCamera
				end
			else
				trail = nil
				point = nil
				point2 = nil
			end
		end,
		Tooltip = 'Shows a trail behind your character'
	})
	
	Texture = Breadcrumbs:CreateTextBox({
		Name = 'Texture',
		Placeholder = 'Texture Id',
		Function = function(enter)
			if enter and trail then
				trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
			end
		end
	})
	FadeIn = Breadcrumbs:CreateColorSlider({
		Name = 'Fade In',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
			end
		end
	})
	FadeOut = Breadcrumbs:CreateColorSlider({
		Name = 'Fade Out',
		Function = function(hue, sat, val)
			if trail then
				trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
			end
		end
	})
	Lifetime = Breadcrumbs:CreateSlider({
		Name = 'Lifetime',
		Min = 1,
		Max = 5,
		Decimal = 10,
		Function = function(val)
			if trail then
				trail.Lifetime = val
			end
		end,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Default = 3
	})
	Thickness = Breadcrumbs:CreateSlider({
		Name = 'Thickness',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Function = function(val)
			if point then
				point.Position = Vector3.new(0, val - 2.7, 0)
			end
			if point2 then
				point2.Position = Vector3.new(0, -val - 2.7, 0)
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Default = 0.1
	})
end)

run(function()
	local Cape
	local Texture
	local part, motor
	
	local function createMotor(char)
		if motor then
			motor:Destroy()
		end
	
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	Cape = vape.Legit:CreateModule({
		Name = 'Cape',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_cape.png'),
		Function = function(callback)
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
				local capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Parent = part
	
				if Texture.Value:find('.webm') then
					local decal = Instance.new('VideoFrame')
					decal.Video = getvapeasset(Texture.Value)
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Looped = true
					decal.Parent = capesurface
					decal:Play()
				else
					local decal = Instance.new('ImageLabel')
					decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
					decal.Size = UDim2.fromScale(1, 1)
					decal.BackgroundTransparency = 1
					decal.Parent = capesurface
				end
	
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.AssemblyLinearVelocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape.Enabled
			else
				part = nil
				motor = nil
			end
		end,
		Tooltip = 'Add\'s a cape to your character'
	})
	
	Texture = Cape:CreateTextBox({
		Name = 'Texture'
	})
end)

run(function()
	local ChinaHat
	local Material
	local Color
	local hat
	
	ChinaHat = vape.Legit:CreateModule({
		Name = 'China Hat',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_chinahat.png'),
		Function = function(callback)
			if callback then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
	
				hat = Instance.new('MeshPart')
				hat.Size = Vector3.new(3, 0.7, 3)
				hat.Name = 'ChinaHat'
				hat.Material = Enum.Material[Material.Value]
				hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				hat.CanCollide = false
				hat.CanQuery = false
				hat.Massless = true
				hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
				hat.Transparency = 1 - Color.Opacity
				hat.Parent = gameCamera
				hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = hat
				weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
				weld.Parent = hat
	
				ChinaHat:Clean(hat)
				ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					if weld then
						weld:Destroy()
					end
					hat.Parent = gameCamera
					hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
					hat.AssemblyLinearVelocity = Vector3.zero
					weld = Instance.new('WeldConstraint')
					weld.Part0 = hat
					weld.Part1 = char.Head
					weld.Parent = hat
				end))
	
				repeat
					hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
					task.wait()
				until not ChinaHat.Enabled
			else
				hat = nil
			end
		end,
		Tooltip = 'Puts a china hat on your character (ty mastadawn)'
	})
	
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = ChinaHat:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if hat then
				hat.Material = Enum.Material[val]
			end
		end
	})
	Color = ChinaHat:CreateColorSlider({
		Name = 'Hat Color',
		DefaultOpacity = 0.7,
		Function = function(hue, sat, val, opacity)
			if hat then
				hat.Color = Color3.fromHSV(hue, sat, val)
				hat.Transparency = 1 - opacity
			end
		end
	})
end)

run(function()
	local Clock
	local ClockType
	local ShowDate
	local TwentyFourHour
	local Background
	local BackgroundColor
	local shadows = {}
	local skippedticks = {[8] = true, [9] = true, [10] = true, [14] = true, [15] = true, [16] = true, [20] = true, [21] = true, [22] = true}
	local localtime, utctime = os.date('*t'), os.date('!*t')
	local timezone = ((localtime.yday - utctime.yday) * 24) + localtime.hour - utctime.hour
	timezone = timezone > 12 and timezone - 24 or (timezone < -12 and timezone + 24 or timezone)
	local americandate = timezone <= -2 and timezone >= -11
	local holder, analog, digital, hand
	local analoghour, analogminute, analogweekday, analogdate, analogmeridiem
	local digitalhour, digitalminute, digitalmeridiem, digitaldate, digitalweekday
	
	local function addLabel(parent, textsize, alignment)
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontDisplay
		label.Size = UDim2.fromOffset(200, textsize + 6)
		label.Text = ''
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = textsize
		label.TextXAlignment = alignment
		label.Parent = parent
		local shadow = label:Clone()
		shadow.Name = 'Shadow'
		shadow.TextColor3 = Color3.new()
		shadow.TextTransparency = 0.498
		shadow.Visible = false
		shadow.ZIndex = 0
		shadow.Parent = parent
		shadows[label] = shadow
	
		return label
	end
	
	local function placeLabel(label, x, centery)
		label.Position = UDim2.fromOffset(label.TextXAlignment == Enum.TextXAlignment.Right and x - 200 or x, centery - (label.Size.Y.Offset / 2))
		shadows[label].Position = label.Position + UDim2.fromOffset(1, 1)
	end
	
	local function refreshSize()
		if ClockType.Value == 'Digital' then
			holder.Size = UDim2.fromOffset(140 + (ShowDate.Enabled and 48 or 0) + (TwentyFourHour.Enabled and 0 or 24), 64)
			return
		end
	
		holder.Size = UDim2.fromOffset(140, 130)
	end
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local now = os.date('*t')
		local hour = TwentyFourHour.Enabled and now.hour or (now.hour > 12 and now.hour - 12 or (now.hour == 0 and 12 or now.hour))
		local hourtext = string.format('%02d', hour)
		local minutetext = string.format('%02d', now.min)
		local meridiem = now.hour >= 12 and 'pm' or 'am'
		local weekday = os.date('%a'):lower()
		local datetext = string.format(ClockType.Value == 'Digital' and '%02d / %02d' or '%02d/%02d', americandate and now.month or now.day, americandate and now.day or now.month)
	
		if ClockType.Value == 'Digital' then
			digitalhour.Text = hourtext
			digitalminute.Text = minutetext
			digitalmeridiem.Text = meridiem
			digitaldate.Text = datetext
			digitalweekday.Text = weekday
			shadows[digitalhour].Text = hourtext
			shadows[digitalminute].Text = minutetext
			shadows[digitalmeridiem].Text = meridiem
			shadows[digitaldate].Text = datetext
			shadows[digitalweekday].Text = weekday
			placeLabel(digitalmeridiem, 78 + getfontbounds(minutetext, 48 * uipallet.DisplayScale, uipallet.FontDisplay).X, 46)
			placeLabel(digitaldate, holder.Size.X.Offset - 12, 24)
			placeLabel(digitalweekday, holder.Size.X.Offset - 12, 40)
	
			return
		end
	
		analoghour.Text = hourtext
		analogminute.Text = minutetext
		analogweekday.Text = weekday
		analogdate.Text = datetext
		analogmeridiem.Text = meridiem
		shadows[analoghour].Text = hourtext
		shadows[analogminute].Text = minutetext
		shadows[analogweekday].Text = weekday
		shadows[analogdate].Text = datetext
		shadows[analogmeridiem].Text = meridiem
		hand.Rotation = (hour * 30) + (now.min / 2)
	end
	
	Clock = vape.Legit:CreateModule({
		Name = 'Clock',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_clock.png'),
		Function = function(callback)
			if callback then
				repeat
					update()
					task.wait(1)
				until not Clock.Enabled
			end
		end,
		Size = UDim2.fromOffset(140, 130),
		Tooltip = 'Draws a clock with the current real-world time'
	})
	
	ClockType = Clock:CreateDropdown({
		Name = 'Clock Type',
		List = {'Analog', 'Digital'},
		Function = function(value)
			if holder then
				analog.Visible = value == 'Analog'
				digital.Visible = value == 'Digital'
				ShowDate.Object.Visible = value == 'Digital'
				refreshSize()
				update()
			end
		end
	})
	ShowDate = Clock:CreateToggle({
		Name = 'Show date',
		Function = function(callback)
			if holder then
				digitaldate.Visible = callback
				digitalweekday.Visible = callback
				shadows[digitaldate].Visible = callback and not Background.Enabled
				shadows[digitalweekday].Visible = callback and not Background.Enabled
				refreshSize()
			end
		end,
		Default = true
	})
	TwentyFourHour = Clock:CreateToggle({
		Name = '24 Hour Time',
		Function = function(callback)
			if holder then
				analogmeridiem.Visible = not callback
				digitalmeridiem.Visible = not callback
				shadows[analogmeridiem].Visible = not callback and not Background.Enabled
				shadows[digitalmeridiem].Visible = not callback and not Background.Enabled
				refreshSize()
				update()
			end
		end
	})
	Background = Clock:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				holder.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
	
				for i, v in shadows do
					v.Visible = not callback and i.Visible
				end
			end
		end,
		Default = true
	})
	BackgroundColor = Clock:CreateColorSlider({
		Name = 'Background Color',
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
			end
		end,
		Darker = true
	})
	holder = Clock.Children
	holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	holder.BackgroundTransparency = 0.6
	local holdercorner = Instance.new('UICorner')
	holdercorner.CornerRadius = UDim.new(0, 4)
	holdercorner.Parent = holder
	analog = Instance.new('Frame')
	analog.BackgroundTransparency = 1
	analog.Name = 'Analog'
	analog.Size = UDim2.fromScale(1, 1)
	analog.Parent = holder
	digital = Instance.new('Frame')
	digital.BackgroundTransparency = 1
	digital.Name = 'Digital'
	digital.Size = UDim2.fromScale(1, 1)
	digital.Visible = false
	digital.Parent = holder
	for i = 0, 23 do
		if not skippedticks[i] then
			local angle = math.rad(i * 15) - (math.pi / 2)
			local x = math.cos(angle) * 50 + 68.5
			local y = math.sin(angle) * 50 + 65.5
			local tick = Instance.new('Frame')
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.BackgroundColor3 = Color3.new(1, 1, 1)
			tick.BorderSizePixel = 0
			tick.Position = UDim2.fromOffset(x, y)
			tick.Size = UDim2.fromOffset(3, 3)
			tick.Parent = analog
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = tick
		end
	end
	hand = Instance.new('Frame')
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.BackgroundColor3 = Color3.fromRGB(6, 161, 126)
	hand.BorderSizePixel = 0
	hand.Name = 'Hand'
	hand.Position = UDim2.fromOffset(70, 65)
	hand.Size = UDim2.fromOffset(4, 52)
	hand.Parent = analog
	analoghour = addLabel(analog, 44 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	analogminute = addLabel(analog, 44 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	analogweekday = addLabel(analog, 13 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	analogdate = addLabel(analog, 13 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	analogmeridiem = addLabel(analog, 13 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	digitalhour = addLabel(digital, 48 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	digitalminute = addLabel(digital, 48 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	digitalmeridiem = addLabel(digital, 16 * uipallet.DisplayScale, Enum.TextXAlignment.Left)
	digitaldate = addLabel(digital, 16 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	digitalweekday = addLabel(digital, 16 * uipallet.DisplayScale, Enum.TextXAlignment.Right)
	local colon = Instance.new('Frame')
	colon.AnchorPoint = Vector2.new(0.5, 0.5)
	colon.BackgroundColor3 = Color3.new(1, 1, 1)
	colon.BorderSizePixel = 0
	colon.Name = 'Colon'
	colon.Position = UDim2.fromOffset(70, 32)
	colon.Size = UDim2.fromOffset(4, 4)
	colon.Parent = digital
	local coloncorner = Instance.new('UICorner')
	coloncorner.CornerRadius = UDim.new(1, 0)
	coloncorner.Parent = colon
	placeLabel(analoghour, 56, 37.5)
	placeLabel(analogminute, 130, 88.7)
	placeLabel(analogweekday, 20, 90.5)
	placeLabel(analogdate, 20, 106.5)
	placeLabel(analogmeridiem, 130, 18.1)
	placeLabel(digitalhour, 60, 34)
	placeLabel(digitalminute, 78, 34)
	ShowDate.Object.Visible = ClockType.Value == 'Digital'
	update()
end)

run(function()
	local Compass
	local Background
	local BackgroundColor
	local slots = {}
	local last = {}
	local cardinals = {[0] = 'N', [45] = 'NE', [90] = 'E', [135] = 'SE', [180] = 'S', [225] = 'SW', [270] = 'W', [315] = 'NW'}
	local tickstep = (616 + 8) / 1400
	local degreestep = tickstep * 10
	local stripcentre = tickstep + 70 * degreestep
	local majorsize = UDim2.fromOffset(2, 12)
	local majorposition = UDim2.fromOffset(0, 32)
	local minorsize = UDim2.fromOffset(2, 4)
	local minorposition = UDim2.fromOffset(0, 36)
	local platecolor = Color3.fromRGB(230, 230, 230)
	local mutedcolor = Color3.fromRGB(163, 163, 163)
	local whitecolor = Color3.new(1, 1, 1)
	local holder, strip, headinglabel
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local look = gameCamera.CFrame.LookVector
		local heading = math.deg(math.atan2(look.X, -look.Z)) % 360
		local plain = not Background.Enabled
		local index = 0
		local degrees = math.floor(heading)
		if degrees ~= last.degrees then
			last.degrees = degrees
			headinglabel.Text = tostring(degrees)
		end
	
		for value = math.ceil((heading - 70) / 5) * 5, heading + 70, 5 do
			index += 1
			local slot = slots[index]
			local normalized = value % 360
			local major = normalized % 45 == 0
			slot.Object.Position = UDim2.fromOffset(tickstep + (value - heading + 70) * degreestep, 0)
			slot.Object.Visible = true
			slot.Bar.Position = major and majorposition or minorposition
			slot.Bar.Size = major and majorsize or minorsize
			slot.Bar.BackgroundTransparency = major and 0.6 or 0.624
			slot.Label.Visible = major or normalized % 15 == 0
	
			if slot.Label.Visible and (slot.Value ~= normalized or plain ~= last.plain) then
				slot.Value = normalized
				slot.Label.Text = major and cardinals[normalized] or tostring(math.floor(normalized))
				slot.Label.FontFace = (major or plain) and uipallet.FontBold or uipallet.Font
				slot.Label.TextColor3 = plain and platecolor or (major and whitecolor or mutedcolor)
			end
		end
	
		last.plain = plain
	
		for i2, v2 in slots do
			if i2 > index then
				v2.Object.Visible = false
			end
		end
	end
	
	Compass = vape.Legit:CreateModule({
		Name = 'Compass',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_compass.png'),
		Function = function(callback)
			if callback then
				Compass:Clean(runService.RenderStepped:Connect(update))
			end
		end,
		Size = UDim2.fromOffset(616, 60),
		Tooltip = 'Shows a compass indicating your direction'
	})
	
	Background = Compass:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				holder.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
			end
		end,
		Default = true
	})
	BackgroundColor = Compass:CreateColorSlider({
		Name = 'Background Color',
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
			end
		end,
		Darker = true
	})
	holder = Compass.Children
	holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	holder.BackgroundTransparency = 0.6
	local holdercorner = Instance.new('UICorner')
	holdercorner.CornerRadius = UDim.new(0, 4)
	holdercorner.Parent = holder
	strip = Instance.new('Frame')
	strip.BackgroundTransparency = 1
	strip.ClipsDescendants = true
	strip.Name = 'Strip'
	strip.Position = UDim2.fromOffset(0, -20)
	strip.Size = UDim2.fromOffset(616, 80)
	strip.Parent = holder
	headinglabel = Instance.new('TextLabel')
	headinglabel.AnchorPoint = Vector2.new(0.5, 0)
	headinglabel.BackgroundTransparency = 1
	headinglabel.FontFace = uipallet.FontBold
	headinglabel.Position = UDim2.fromOffset(stripcentre, 0)
	headinglabel.Size = UDim2.fromOffset(200, 16)
	headinglabel.TextColor3 = platecolor
	headinglabel.TextSize = 12
	headinglabel.Parent = strip
	local arrow = Instance.new('ImageLabel')
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.BackgroundTransparency = 1
	arrow.Image = getvapeasset('kingvape/assets/new/compassarrow.png')
	arrow.Position = UDim2.fromOffset(stripcentre, 15)
	arrow.Size = UDim2.fromOffset(19, 32)
	arrow.Parent = strip
	for index = 1, 29 do
		local slot = Instance.new('Frame')
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.new()
		slot.Visible = false
		slot.Parent = strip
		local bar = Instance.new('Frame')
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.BackgroundColor3 = whitecolor
		bar.BorderSizePixel = 0
		bar.Position = majorposition
		bar.Size = majorsize
		bar.Parent = slot
		local label = Instance.new('TextLabel')
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontBold
		label.Position = UDim2.fromOffset(0, 43)
		label.Size = UDim2.fromOffset(60, 20)
		label.TextColor3 = whitecolor
		label.TextSize = 11
		label.Parent = slot
		slots[index] = {Object = slot, Bar = bar, Label = label}
	end
end)

run(function()
	local Coords
	local DisplayType
	local Background
	local BackgroundColor
	local horizontalAxes = {}
	local verticalAxes = {}
	local coords = {}
	local positives = {}
	local last = {}
	local positivecolor = Color3.fromRGB(5, 134, 105)
	local negativecolor = Color3.fromRGB(250, 50, 56)
	local trianglearrow = getvapeasset('kingvape/assets/new/triangle.png')
	local digitWidth = getfontbounds('0', 19, uipallet.Font).X
	local holder, horizontal, vertical
	local horizontalmaterial, verticalmaterial
	
	local function addLabel(parent, textsize, textcolor)
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.Font
		label.Size = UDim2.fromOffset(200, 20)
		label.TextColor3 = textcolor
		label.TextSize = textsize
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = parent
	
		return label
	end
	
	local function addArrow(parent)
		local box = Instance.new('Frame')
		box.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
		box.BackgroundTransparency = 0.431
		box.Size = UDim2.fromOffset(16, 16)
		box.Parent = parent
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = box
		local triangle = Instance.new('ImageLabel')
		triangle.BackgroundTransparency = 1
		triangle.Image = trianglearrow
		triangle.Size = UDim2.fromOffset(8, 4)
		triangle.Parent = box
	
		return box, triangle
	end
	
	local function addDivider(parent, size)
		local divider = Instance.new('Frame')
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.8
		divider.BorderSizePixel = 0
		divider.Size = size
		divider.Parent = parent
	
		return divider
	end
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		if not entitylib.isAlive then return end
	
		local pos = entitylib.character.RootPart.Position
		local look = gameCamera.CFrame.LookVector
		local material = entitylib.character.Humanoid.FloorMaterial.Name
		local x, y, z = math.round(pos.X), math.round(pos.Y), math.round(pos.Z)
		local positivex, positivez = look.X > 0, look.Z > 0
		if last.x == x and last.y == y and last.z == z and last.positivex == positivex and last.positivez == positivez and last.material == material and last.display == DisplayType.Value then return end
	
		last.x, last.y, last.z, last.positivex, last.positivez, last.material, last.display = x, y, z, positivex, positivez, material, DisplayType.Value
		coords[1] = tostring(x)
		coords[2] = tostring(y)
		coords[3] = tostring(z)
		positives[1] = positivex
		positives[3] = positivez
	
		if DisplayType.Value == 'Vertical' then
			for i, v in verticalAxes do
				v.Value.Text = coords[i]
	
				if v.Triangle then
					v.Triangle.ImageColor3 = positives[i] and positivecolor or negativecolor
					v.Triangle.Position = UDim2.fromOffset(4, positives[i] and 5 or 6)
					v.Triangle.Rotation = positives[i] and 180 or 0
				end
			end
	
			verticalmaterial.Text = material
			return
		end
	
		local offset = 20
	
		for i, v in horizontalAxes do
			v.Label.Position = UDim2.fromOffset(offset, 16)
			offset += v.Width + 5
			v.Value.Text = coords[i]
			v.Value.Position = UDim2.fromOffset(offset, 13)
			offset += math.max(44, 10 + digitWidth * #coords[i])
	
			if v.Triangle then
				v.Arrow.Position = UDim2.fromOffset(offset - 8, 18)
				v.Triangle.ImageColor3 = positives[i] and positivecolor or negativecolor
				v.Triangle.Position = UDim2.fromOffset(4, positives[i] and 5 or 6)
				v.Triangle.Rotation = positives[i] and 180 or 0
			end
	
			if v.Divider then
				offset += v.Triangle and 20 or 0
				v.Divider.Position = UDim2.fromOffset(offset - 1, 18)
				offset += 20
			end
		end
	
		horizontalmaterial.Text = material
		holder.Size = UDim2.fromOffset(offset + 24, 70)
	end
	
	Coords = vape.Legit:CreateModule({
		Name = 'Coords',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_coords.png'),
		Function = function(callback)
			if callback then
				Coords:Clean(runService.RenderStepped:Connect(update))
			end
		end,
		Size = UDim2.fromOffset(280, 70),
		Tooltip = 'Shows your current XYZ coordinates'
	})
	
	DisplayType = Coords:CreateDropdown({
		Name = 'Display Type',
		List = {'Horizontal', 'Vertical'},
		Function = function(value)
			if holder then
				horizontal.Visible = value == 'Horizontal'
				vertical.Visible = value == 'Vertical'
				holder.Size = UDim2.fromOffset(value == 'Vertical' and 140 or 280, value == 'Vertical' and 180 or 70)
			end
		end
	})
	Background = Coords:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				holder.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
			end
		end,
		Default = true
	})
	BackgroundColor = Coords:CreateColorSlider({
		Name = 'Background Color',
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
			end
		end,
		Darker = true
	})
	holder = Coords.Children
	holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	holder.BackgroundTransparency = 0.6
	local holdercorner = Instance.new('UICorner')
	holdercorner.CornerRadius = UDim.new(0, 4)
	holdercorner.Parent = holder
	horizontal = Instance.new('Frame')
	horizontal.BackgroundTransparency = 1
	horizontal.Name = 'Horizontal'
	horizontal.Size = UDim2.fromScale(1, 1)
	horizontal.Parent = holder
	vertical = Instance.new('Frame')
	vertical.BackgroundTransparency = 1
	vertical.Name = 'Vertical'
	vertical.Size = UDim2.fromScale(1, 1)
	vertical.Visible = false
	vertical.Parent = holder
	for i2, v2 in {'X', 'Y', 'Z'} do
		local v = {Width = getfontbounds(v2, 12, uipallet.Font).X}
		v.Label = addLabel(horizontal, 12, Color3.new(1, 1, 1))
		v.Label.Text = v2
		v.Value = addLabel(horizontal, 19, Color3.new(1, 1, 1))
	
		if v2 ~= 'Y' then
			v.Arrow, v.Triangle = addArrow(horizontal)
		end
	
		if v2 ~= 'Z' then
			v.Divider = addDivider(horizontal, UDim2.fromOffset(2, 16))
		end
	
		horizontalAxes[i2] = v
	end
	for i2, v2 in {'X', 'Y', 'Z'} do
		local v = {}
		v.Label = addLabel(vertical, 11, Color3.new(1, 1, 1))
		v.Label.Text = v2
		v.Label.Position = UDim2.fromOffset(16, 16 + (i2 - 1) * 45)
		v.Value = addLabel(vertical, 17, Color3.new(1, 1, 1))
		v.Value.Position = UDim2.fromOffset(21 + getfontbounds(v2, 11, uipallet.Font).X, 13 + (i2 - 1) * 45)
	
		if v2 ~= 'Y' then
			v.Arrow, v.Triangle = addArrow(vertical)
			v.Arrow.Position = UDim2.fromOffset(108, v2 == 'X' and 18 or 105)
		end
	
		verticalAxes[i2] = v
	end
	for i = 1, 3 do
		local divider = addDivider(vertical, UDim2.fromOffset(110, 2))
		divider.Position = UDim2.fromOffset(16, 2 + i * 45)
	end
	local horizontallabel = addLabel(horizontal, 12, Color3.new(1, 1, 1))
	horizontallabel.Text = 'MATERIAL:'
	horizontallabel.Position = UDim2.fromOffset(20, 41)
	horizontalmaterial = addLabel(horizontal, 12, Color3.fromRGB(255, 160, 84))
	horizontalmaterial.Position = UDim2.fromOffset(20 + getfontbounds('MATERIAL: ', 12, uipallet.Font).X, 41)
	local verticallabel = addLabel(vertical, 11, Color3.new(1, 1, 1))
	verticallabel.Text = 'MATERIAL:'
	verticallabel.Position = UDim2.fromOffset(16, 146)
	verticalmaterial = addLabel(vertical, 11, Color3.fromRGB(255, 160, 84))
	verticalmaterial.Position = UDim2.fromOffset(24 + getfontbounds('MATERIAL:', 11, uipallet.Font).X, 146)
end)

run(function()
	local Disguise
	local Mode
	local IDBox
	local cloned = {}
	
	local function itemAdded(obj, manual)
		if (obj:IsA('Accessory') or obj:IsA('ShirtGraphic') or obj:IsA('Shirt') or obj:IsA('Pants') or obj:IsA('BodyColors') or manual) and not cloned[obj] then
			obj:ClearAllChildren()
			task.defer(obj.Destroy, obj)
		end
	end
	
	local function localAdded(char)
		table.clear(cloned)
		if Mode.Value == 'Character' then
			local success, description = pcall(function()
				return playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
			end)
	
			if success and Disguise.Enabled then
				char.Character.Archivable = true
				local clone = char.Character:Clone()
				clone.Parent = game
	
				local original = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
					HeightScale = 1,
					SetEmotes = function() end,
					SetEquippedEmotes = function() end
				}
	
				original.JumpAnimation = description.JumpAnimation
				description.HeightScale = original.HeightScale
				clone:FindFirstChildWhichIsA('Humanoid'):ApplyDescriptionResetAsync(description)
	
				Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))
				for _, v in char.Character:GetChildren() do
					itemAdded(v)
				end
	
				for _, v in clone:GetChildren() do
					cloned[v] = true
					if v:IsA('Accessory') then
						for _, v in v:GetDescendants() do
							if v:IsA('Weld') and v.Part1 then
								v.Part1 = char.Character:FindFirstChild(v.Part1.Name)
							elseif v:IsA('RigidConstraint') then
								v.Attachment1 = char.Character:FindFirstChild(v.Attachment1.Name, true)
							end
						end
	
						v.Parent = char.Character
					elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
						v.Parent = char.Character
					elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
						char.Head.MeshId = v.MeshId
					end
				end
	
				local face = char.Character:FindFirstChild('face', true)
				local cface = clone:FindFirstChild('face', true)
	
				if face then
					itemAdded(face, true)
				end
	
				if cface then
					cface.Parent = char.Head
				end
	
				original:SetEmotes(description:GetEmotes())
				original:SetEquippedEmotes(description:GetEquippedEmotes())
				description:Destroy()
				clone:ClearAllChildren()
				clone:Destroy()
			elseif description then
				description:Destroy()
			end
		else
			local success, data = pcall(function()
				data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
			end)
	
			if success and Disguise.Enabled then
				if data.BundleType == 'AvatarAnimations' then
					local animate = char.Character:FindFirstChild('Animate')
					if not animate then return end
	
					for _, v in desc.Items do
						local itemtype = v.Name:split(' ')[2]:lower()
						if itemtype ~= 'animation' then
							local suc, obj = pcall(function()
								return game:GetObjects('rbxassetid://'..item.Id)
							end)
	
							if suc then
								animate[itemtype]:FindFirstChildWhichIsA('Animation').AnimationId = obj[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
							end
						end
					end
				else
					notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
				end
			elseif type(data) == 'table' then
				table.clear(data)
			end
		end
	end
	
	Disguise = vape.Legit:CreateModule({
		Name = 'Disguise',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_disguise.png'),
		Function = function(callback)
			if callback then
				Disguise:Clean(entitylib.Events.LocalAdded:Connect(localAdded))
				if entitylib.isAlive then
					task.spawn(localAdded, entitylib.character)
				end
			else
				table.clear(cloned)
			end
		end,
		Tooltip = 'Changes your character or animation to a specific ID (animation packs or userid\'s only)'
	})
	
	Mode = Disguise:CreateDropdown({
		Name = 'Mode',
		List = {'Character', 'Animation'},
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
	IDBox = Disguise:CreateTextBox({
		Name = 'Disguise',
		Placeholder = 'Disguise User Id',
		Function = function()
			if Disguise.Enabled then
				Disguise:Toggle()
				Disguise:Toggle()
			end
		end
	})
end)

run(function()
	local FFlag
	local Flags
	local List
	local prefixes = {'DFFlag', 'DFInt', 'DFLog', 'DFString', 'SFFlag', 'FFlag', 'FInt', 'FLog', 'FString'}
	local marker = 'CVFF1:'
	
	local function unpackFlags(text)
		local size, body = text:match('^'..marker..'(%d+):(.+)$')
		if not size then return text end
	
		local suc, plain = pcall(function()
			return lz4decompress(base64decode(body), tonumber(size))
		end)
		return suc and plain or text
	end
	
	local function apply()
		if not FFlag.Enabled then return end
	
		local applied = 0
		for _, v in List.ListEnabled do
			local name, value = v:match('^%s*(.-)%s*=%s*(.-)%s*$')
			for _, v in prefixes do
				if name and name:sub(1, #v) == v then
					name = name:sub(#v + 1)
					break
				end
			end
	
			if name and name ~= '' and value ~= '' and pcall(setfflag, name, value) then
				applied += 1
			end
		end
	
		if applied > 0 then
			notif('Vape', `Applied {applied} fflag{applied == 1 and '' or 's'}, join a new game for them to take effect`, 12, 'info')
		end
	end
	
	local function ingest(text, source)
		text = unpackFlags(text)
		local suc, json = pcall(function()
			return httpService:JSONDecode(text)
		end)
	
		if not suc or typeof(json) ~= 'table' then
			notif('Vape', `{source} is not valid fflag json`, 12, 'warning')
			return
		end
	
		local added, dropped = 0, 0
		for i, v in json do
			local entry
			for _, v2 in prefixes do
				if typeof(i) == 'string' and #i > #v2 and i:sub(1, #v2) == v2 and (typeof(v) == 'string' or typeof(v) == 'number' or typeof(v) == 'boolean') then
					entry = `{i}={tostring(v)}`
					break
				end
			end
	
			if entry and not table.find(List.List, entry) then
				table.insert(List.List, entry)
				table.insert(List.ListEnabled, entry)
				added += 1
			elseif not entry then
				dropped += 1
			end
		end
	
		List:ChangeValue()
		notif('Vape', `Took {added} fflag{added == 1 and '' or 's'} from {source}{dropped > 0 and `, dropped {dropped} it did not recognise` or ''}`, 12, added > 0 and 'info' or 'warning')
	end
	
	FFlag = vape.Legit:CreateModule({
		Name = 'FFlagEditor',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_fflageditor.png'),
		Function = function(callback)
			if callback then
				apply()
			else
				notif('Vape', 'Inorder to disable fflags you have applied, You need to restart roblox', 20, 'info')
			end
		end
	})
	
	List = FFlag:CreateTextList({
		Name = 'Flags',
		Function = apply,
		Tooltip = 'One flag per entry as Name=Value, click a flag to leave it out without deleting it\nSaved with your profile, so it travels with an exported config'
	})
	Flags = FFlag:CreateTextBox({
		Name = 'FFlags',
		Placeholder = 'json format only',
		Function = function(enter)
			if enter and Flags.Value ~= '' then
				ingest(Flags.Value, 'the box')
				Flags:SetValue('')
			end
		end
	})
	FFlag:CreateButton({
		Name = 'Import from file',
		Function = function()
			if not isfile('kingvape/fflags.json') then
				notif('Vape', 'No kingvape/fflags.json to read', 12, 'warning')
				return
			end
	
			ingest(readfile('kingvape/fflags.json'), 'kingvape/fflags.json')
		end
	})
	FFlag:CreateButton({
		Name = 'Export to file',
		Function = function()
			local json = {}
			for _, v in List.ListEnabled do
				local name, value = v:match('^%s*(.-)%s*=%s*(.-)%s*$')
				if name and name ~= '' then
					json[name] = value
				end
			end
	
			local plain = httpService:JSONEncode(json)
			local suc2, blob = pcall(function()
				return marker..#plain..':'..base64encode(lz4compress(plain))
			end)
	
			local copied, packed = plain, false
			if suc2 and unpackFlags(blob) == plain then
				copied, packed = blob, true
			end
			writefile('kingvape/fflags.json', plain)
	
			if setclipboard then
				setclipboard(copied)
			end
	
			notif('Vape', packed and `Wrote kingvape/fflags.json and copied {#copied} characters to your clipboard, {math.floor(#copied / #plain * 100)}% of the raw json` or `Wrote kingvape/fflags.json and copied the raw json, packing it did not read back so it was left alone`, 12, packed and 'info' or 'warning')
		end
	})
	FFlag:CreateButton({
		Name = 'Reset',
		Function = function()
			table.clear(List.List)
			table.clear(List.ListEnabled)
			List:ChangeValue()
			notif('Vape', 'Cleared the list, restart roblox to drop the flags already applied', 20, 'info')
		end
	})
end)

run(function()
	local FOV
	local Value
	local oldfov
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_fov.png'),
		Function = function(callback)
			if callback then
				oldfov = gameCamera.FieldOfView
				repeat
					gameCamera.FieldOfView = Value.Value
					task.wait()
				until not FOV.Enabled
			else
				gameCamera.FieldOfView = oldfov
			end
		end,
		Tooltip = 'Adjusts camera vision'
	})
	
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)

run(function()
	local FPS
	local label
	
	FPS = vape.Legit:CreateModule({
		Name = 'FPS',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_fps.png'),
		Function = function(callback)
			if callback then
				local frames = {}
				local startClock = os.clock()
				local updateTick = tick()
	
				FPS:Clean(runService.Heartbeat:Connect(function()
					local updateClock = os.clock()
					for i = #frames, 1, -1 do
						frames[i + 1] = frames[i] >= updateClock - 1 and frames[i] or nil
					end
	
					frames[1] = updateClock
					if updateTick < tick() then
						updateTick = tick() + 1
						label.Text = math.floor(os.clock() - startClock >= 1 and #frames or #frames / (os.clock() - startClock))..' FPS'
					end
				end))
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current framerate'
	})
	
	FPS:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	FPS:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = 'inf FPS'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = FPS.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local Keystrokes
	local KeyStyle
	local MouseStyle
	local ShowSpacebar
	local ShowCpsOnly
	local keys = {}
	local leftclicks = {}
	local rightclicks = {}
	local arrowicons = {
		W = getvapeasset('kingvape/assets/new/key_up.png'),
		A = getvapeasset('kingvape/assets/new/key_left.png'),
		S = getvapeasset('kingvape/assets/new/key_down.png'),
		D = getvapeasset('kingvape/assets/new/key_right.png')
	}
	local keybinds = {
		[Enum.KeyCode.W] = 'W',
		[Enum.KeyCode.A] = 'A',
		[Enum.KeyCode.S] = 'S',
		[Enum.KeyCode.D] = 'D',
		[Enum.KeyCode.Space] = 'Space'
	}
	local releasedbackground = Color3.fromRGB(20, 20, 20)
	local pressedtext = Color3.fromRGB(20, 20, 20)
	local keytween = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
	local holder, mouseicons, cpsholder, cpsbackground, cpsdivider, cpsleft, cpsright, cpslabel
	local lmbicon, rmbicon, mmbicon
	
	local function addLabel(parent, name, text)
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontDisplay
		label.Name = name
		label.Size = UDim2.fromOffset(200, 22)
		label.Text = text
		label.TextColor3 = Color3.fromRGB(209, 209, 209)
		label.TextSize = 16 * uipallet.DisplayScale
		label.Parent = parent
	
		return label
	end
	
	local function placeCps(label, x, centery, alignment)
		label.Position = UDim2.fromOffset(alignment == Enum.TextXAlignment.Right and x - 200 or x, centery - 11)
		label.TextXAlignment = alignment
	end
	
	local function placeKey(entry, x, y, width, height)
		entry.Object.Position = UDim2.fromOffset(x, y - 1)
		entry.Object.Size = UDim2.fromOffset(width, height + 1)
		entry.Label.Position = UDim2.fromOffset((width / 2) - 100, 5.75)
		entry.Icon.Position = UDim2.fromOffset((width / 2) - 4.4, 6)
	end
	
	local function pressKey(entry, pressed)
		if entry.Pressed == pressed then return end
	
		entry.Pressed = pressed
		entry.Shadow.Enabled = pressed
	
		tween:Tween(entry.Object, keytween, {
			BackgroundColor3 = pressed and Color3.new(1, 1, 1) or releasedbackground,
			BackgroundTransparency = pressed and 0 or 0.294
		})
	
		tween:Tween(entry.Bar, keytween, {
			BackgroundColor3 = pressed and pressedtext or Color3.new(1, 1, 1)
		})
	
		tween:Tween(entry.Icon, keytween, {
			ImageColor3 = pressed and pressedtext or Color3.new(1, 1, 1)
		})
	
		tween:Tween(entry.Label, keytween, {
			TextColor3 = pressed and pressedtext or Color3.new(1, 1, 1)
		})
	
		if entry.Mouse then
			tween:Tween(entry.Mouse, keytween, {
				ImageColor3 = pressed and Color3.new(1, 1, 1) or releasedbackground,
				ImageTransparency = pressed and 0 or 0.294
			})
		end
	end
	
	local function countClicks(clicks)
		local now = tick()
		while clicks[1] and clicks[1] < now do
			table.remove(clicks, 1)
		end
	
		return #clicks
	end
	
	local function refreshLayout()
		if not holder then return end
	
		local iconstyle = MouseStyle.Value == 'Icon'
		local arrowstyle = KeyStyle.Value == 'Arrow'
		local spacebar = ShowSpacebar.Enabled
	
		for i, v in keys do
			v.Object.Visible = not ShowCpsOnly.Enabled and (i ~= 'Space' or spacebar) and not (iconstyle and (i == 'LMB' or i == 'RMB'))
			v.Label.Visible = not arrowstyle or i == 'LMB' or i == 'RMB' or i == 'Space'
			v.Icon.Visible = arrowstyle and arrowicons[i] ~= nil
			v.Icon.Image = arrowicons[i] or ''
		end
	
		mouseicons.Visible = iconstyle and not ShowCpsOnly.Enabled
		cpsdivider.Visible = not ShowCpsOnly.Enabled
		cpslabel.Visible = ShowCpsOnly.Enabled
		cpsright.Visible = not ShowCpsOnly.Enabled
	
		if ShowCpsOnly.Enabled then
			holder.Size = UDim2.fromOffset(150, 40)
			cpsholder.Position = UDim2.fromOffset(0, 0)
			cpsholder.Size = UDim2.fromOffset(110, 20)
			cpsbackground.Position = UDim2.fromOffset(0, 0)
			cpsbackground.Size = UDim2.fromOffset(39 + getfontbounds('CPS', 16 * uipallet.DisplayScale, uipallet.FontDisplay).X, 24)
			placeCps(cpsleft, 22, 14, Enum.TextXAlignment.Right)
			placeCps(cpslabel, 25, 14, Enum.TextXAlignment.Left)
	
			return
		end
	
		local keysy = iconstyle and 8 or 4
		local mousex = iconstyle and 122 or 0
		local mousey = (iconstyle and keysy - 12 or keysy + 80) + (spacebar and 28 or 0)
		local cpswidth = iconstyle and 80 or 110
		holder.Size = UDim2.fromOffset(108 + (iconstyle and 96 or 0), (iconstyle and 80 or 144) + (spacebar and 28 or 0))
		placeKey(keys.W, 38, keysy - 4, 34, 34)
		placeKey(keys.A, 0, keysy + 38, 34, 34)
		placeKey(keys.S, 38, keysy + 38, 34, 34)
		placeKey(keys.D, 76, keysy + 38, 34, 34)
		placeKey(keys.Space, 0, keysy + 79, 110.5, 22)
		placeKey(keys.LMB, mousex, mousey, 52.7, 32)
		placeKey(keys.RMB, mousex + 56.7, mousey, 52.7, 32)
		mouseicons.Position = UDim2.fromOffset(mousex - 4, mousey)
		cpsholder.Position = UDim2.fromOffset(mousex, mousey + (iconstyle and 44 or 34))
		cpsholder.Size = UDim2.fromOffset(cpswidth, 20)
		cpsbackground.Position = UDim2.fromOffset(0, 4)
		cpsbackground.Size = UDim2.fromOffset(cpswidth, 24)
		cpsdivider.Position = UDim2.fromOffset(cpswidth / 2, 8)
		placeCps(cpsleft, 10, 16, Enum.TextXAlignment.Left)
		placeCps(cpsright, cpswidth - 10, 16, Enum.TextXAlignment.Right)
	end
	
	local function update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		cpsleft.Text = tostring(countClicks(leftclicks))
		cpsright.Text = tostring(countClicks(rightclicks))
	end
	
	local function inputChanged(input, pressed)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local name = keybinds[input.KeyCode]
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			name = 'LMB'
	
			if pressed then
				table.insert(leftclicks, tick() + 1)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			name = 'RMB'
	
			if pressed then
				table.insert(rightclicks, tick() + 1)
			end
		end
	
		if name and keys[name] then
			pressKey(keys[name], pressed)
		end
	end
	
	Keystrokes = vape.Legit:CreateModule({
		Name = 'Keystrokes',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_keystrokes.png'),
		Function = function(callback)
			if callback then
				Keystrokes:Clean(inputService.InputBegan:Connect(function(input)
					inputChanged(input, true)
				end))
	
				Keystrokes:Clean(inputService.InputEnded:Connect(function(input)
					inputChanged(input, false)
				end))
	
				Keystrokes:Clean(runService.RenderStepped:Connect(update))
			else
				for _, v in keys do
					pressKey(v, false)
				end
			end
		end,
		Size = UDim2.fromOffset(108, 172),
		Tooltip = 'Shows when your movement keys or mouse buttons are pressed, as well as mouse clicks per second'
	})
	
	KeyStyle = Keystrokes:CreateDropdown({
		Name = 'Key Style',
		List = {'Keyboard', 'Arrow'},
		Function = function()
			refreshLayout()
		end
	})
	MouseStyle = Keystrokes:CreateDropdown({
		Name = 'Mouse Style',
		List = {'Button', 'Icon'},
		Function = function()
			refreshLayout()
		end
	})
	ShowSpacebar = Keystrokes:CreateToggle({
		Name = 'Show Spacebar',
		Function = function()
			refreshLayout()
		end,
		Default = true
	})
	ShowCpsOnly = Keystrokes:CreateToggle({
		Name = 'Show CPS Only',
		Function = function()
			refreshLayout()
		end
	})
	holder = Keystrokes.Children
	for _, v in {'W', 'A', 'S', 'D', 'Space', 'LMB', 'RMB'} do
		local name = v
		local key = Instance.new('Frame')
		key.BackgroundColor3 = releasedbackground
		key.BackgroundTransparency = 0.294
		key.BorderSizePixel = 0
		key.Name = name
		key.Parent = holder
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = key
		local shadow = Instance.new('UIShadow')
		shadow.BlurRadius = UDim.new(0, 6)
		shadow.Color = Color3.new()
		shadow.Enabled = false
		shadow.Offset = UDim2.new()
		shadow.Spread = UDim2.new()
		shadow.Transparency = 0.404
		shadow.Parent = key
		local label = Instance.new('TextLabel')
		label.BackgroundTransparency = 1
		label.FontFace = uipallet.FontBold
		label.Name = 'Label'
		label.Size = UDim2.fromOffset(200, 20)
		label.Text = name == 'Space' and '' or name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 14
		label.Parent = key
		local icon = Instance.new('ImageLabel')
		icon.BackgroundTransparency = 1
		icon.Name = 'Icon'
		icon.Size = UDim2.fromOffset(8.8, 8.8)
		icon.Visible = false
		icon.Parent = key
		local bar = Instance.new('Frame')
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Name = 'Bar'
		bar.Position = UDim2.new(0.5, 0, 0, 4)
		bar.Size = UDim2.fromOffset(60, 3)
		bar.Visible = name == 'Space'
		bar.Parent = key
		keys[name] = {Object = key, Label = label, Icon = icon, Bar = bar, Shadow = shadow, Pressed = false}
	
	end
	mouseicons = Instance.new('Frame')
	mouseicons.BackgroundTransparency = 1
	mouseicons.Name = 'MouseIcons'
	mouseicons.Size = UDim2.fromOffset(96, 48)
	mouseicons.Visible = false
	mouseicons.Parent = holder
	lmbicon = Instance.new('ImageLabel')
	lmbicon.BackgroundTransparency = 1
	lmbicon.Image = getvapeasset('kingvape/assets/new/key_lmb.png')
	lmbicon.ImageColor3 = releasedbackground
	lmbicon.Name = 'LMB'
	lmbicon.Size = UDim2.fromOffset(50.2, 48)
	lmbicon.Parent = mouseicons
	rmbicon = lmbicon:Clone()
	rmbicon.Image = getvapeasset('kingvape/assets/new/key_rmb.png')
	rmbicon.Name = 'RMB'
	rmbicon.Position = UDim2.fromOffset(40, 0)
	rmbicon.Parent = mouseicons
	mmbicon = Instance.new('ImageLabel')
	mmbicon.BackgroundTransparency = 1
	mmbicon.Image = getvapeasset('kingvape/assets/new/key_mmb.png')
	mmbicon.ImageColor3 = Color3.fromRGB(225, 225, 225)
	mmbicon.Name = 'MMB'
	mmbicon.Position = UDim2.fromOffset(43, 14)
	mmbicon.Size = UDim2.fromOffset(3.9, 13.8)
	mmbicon.Parent = mouseicons
	cpsholder = Instance.new('Frame')
	cpsholder.BackgroundTransparency = 1
	cpsholder.Name = 'CPS'
	cpsholder.Size = UDim2.fromOffset(110, 20)
	cpsholder.Parent = holder
	cpsbackground = Instance.new('Frame')
	cpsbackground.BackgroundColor3 = releasedbackground
	cpsbackground.BackgroundTransparency = 0.294
	cpsbackground.BorderSizePixel = 0
	cpsbackground.Name = 'Background'
	cpsbackground.ZIndex = 0
	cpsbackground.Parent = cpsholder
	local cpscorner = Instance.new('UICorner')
	cpscorner.CornerRadius = UDim.new(0, 5)
	cpscorner.Parent = cpsbackground
	cpsdivider = Instance.new('Frame')
	cpsdivider.BackgroundColor3 = Color3.fromRGB(209, 209, 209)
	cpsdivider.BorderSizePixel = 0
	cpsdivider.Name = 'Divider'
	cpsdivider.Size = UDim2.fromOffset(2, 18)
	cpsdivider.Parent = cpsholder
	cpsleft = addLabel(cpsholder, 'Left', '0')
	cpsright = addLabel(cpsholder, 'Right', '0')
	cpslabel = addLabel(cpsholder, 'Label', 'CPS')
	cpslabel.Visible = false
	keys.LMB.Mouse = lmbicon
	keys.RMB.Mouse = rmbicon
	refreshLayout()
end)

run(function()
	local Memory
	local label
	
	Memory = vape.Legit:CreateModule({
		Name = 'Memory',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_memory.png'),
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(stats.PerformanceStats.Memory:GetValue()))..' MB'
					task.wait(1)
				until not Memory.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the memory currently used by roblox'
	})
	
	Memory:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Memory:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = '0 MB'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Memory.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local Ping
	local label
	
	Ping = vape.Legit:CreateModule({
		Name = 'Ping',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_ping.png'),
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(tonumber(stats.PerformanceStats.Ping:GetValue()))..' ms'
					task.wait(1)
				until not Ping.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current connection speed to the roblox server'
	})
	
	Ping:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Ping:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.new(0, 100, 0, 41)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = '0 ms'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Ping.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = os.clock()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then
			table.clear(alreadypicked)
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat
				task.wait()
				chosensong = list[math.random(1, #list)]
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat
			task.wait()
		until songobj.IsLoaded or not SongBeats.Enabled
	
		if SongBeats.Enabled then
			beattick = os.clock() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_songbeats.png'),
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				SongBeats:Clean(songobj)
				oldfov = gameCamera.FieldOfView
	
				repeat
					if not songobj.Playing then
						choosesong()
					end
	
					if beattick < os.clock() and SongBeats.Enabled and FOV.Enabled then
						beattick = os.clock() + songbpm
						if songtween then
							songtween:Cancel()
						end
	
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {
							FieldOfView = oldfov
						})
	
						songtween:Play()
					end
	
					task.wait()
				until not SongBeats.Enabled
			else
				if songtween then
					songtween:Cancel()
				end
	
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
	
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
	
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then
				songobj.Volume = val / 100
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
end)

run(function()
	local Speedmeter
	local label
	
	Speedmeter = vape.Legit:CreateModule({
		Name = 'Speedmeter',
		Category = 'HUD',
		Icon = getvapeasset('kingvape/assets/new/legit_speedmeter.png'),
		Function = function(callback)
			if callback then
				repeat
					local lastpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					local dt = task.wait(0.2)
					local newpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
					label.Text = math.round(((lastpos - newpos) / dt).Magnitude)..' sps'
				until not Speedmeter.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'A label showing the average velocity in studs'
	})
	
	Speedmeter:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	Speedmeter:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.FontFace = uipallet.Font
	label.Text = '0 sps'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = Speedmeter.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)

run(function()
	local TimeChanger
	local Value
	local old
	
	TimeChanger = vape.Legit:CreateModule({
		Name = 'Time Changer',
		Category = 'Game',
		Icon = getvapeasset('kingvape/assets/new/legit_timechanger.png'),
		Function = function(callback)
			if callback then
				old = lightingService.TimeOfDay
				repeat
					lightingService.TimeOfDay = Value.Value..':00:00'
					task.wait()
				until not TimeChanger.Enabled
			else
				lightingService.TimeOfDay = old
				old = nil
			end
		end,
		Tooltip = 'Change the time of the current world'
	})
	
	Value = TimeChanger:CreateSlider({
		Name = 'Time',
		Min = 0,
		Max = 24,
		Function = function(val)
			if TimeChanger.Enabled then
				lightingService.TimeOfDay = val..':00:00'
			end
		end,
		Default = 12
	})
end)

-- [KingVape Exclusive Modules]
run(function()
	local AutoParry = {Enabled = false}
	local ParryRange = {Value = 12}
	local ParryDelay = {Value = 0.05}
	local AutoCounter = {Enabled = true}
	local ParrySound = {Enabled = true}
	local lastParry = 0

	local combatCategory = (vape.Categories and vape.Categories.Combat) or vape.Combat
	if not combatCategory then return end

	AutoParry = combatCategory:CreateModule({
		Name = 'AutoParry',
		Tooltip = 'Automatically parries incoming attacks and performs a counter-attack.',
		Function = function(callback)
			if callback then
				AutoParry:Clean(runService.Heartbeat:Connect(function()
					if not lplr.Character or not lplr.Character:FindFirstChild('HumanoidRootPart') then return end
					if os.clock() - lastParry < (ParryDelay.Value + 0.3) then return end

					local myPos = lplr.Character.HumanoidRootPart.Position
					for _, plr in playersService:GetPlayers() do
						if plr ~= lplr and plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and not isFriend(plr) then
							local char = plr.Character
							local root = char.HumanoidRootPart
							local dist = (root.Position - myPos).Magnitude

							if dist <= ParryRange.Value then
								local hum = char:FindFirstChildWhichIsA('Humanoid')
								if hum and hum.Health > 0 then
									local isFacing = (root.CFrame.LookVector:Dot((myPos - root.Position).Unit)) > 0.4
									if isFacing then
										lastParry = os.clock()
										if ParrySound.Enabled then
											pcall(function()
												local sound = Instance.new('Sound', workspace)
												sound.SoundId = 'rbxassetid://6732924371'
												sound.Volume = 0.8
												sound:Play()
												task.delay(1, function() sound:Destroy() end)
											end)
										end

										if AutoCounter.Enabled then
											pcall(function()
												local tool = lplr.Character:FindFirstChildWhichIsA('Tool')
												if tool then tool:Activate() end
											end)
										end
										break
									end
								end
							end
						end
					end
				end))
			end
		end
	})
	ParryRange = AutoParry:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 20,
		Default = 12,
		Suffix = ' studs'
	})
	ParryDelay = AutoParry:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 0.2,
		Decimal = 100,
		Default = 0.05,
		Suffix = 's'
	})
	AutoCounter = AutoParry:CreateToggle({
		Name = 'Auto Counter',
		Default = true,
		Tooltip = 'Instantly hits back after parrying'
	})
	ParrySound = AutoParry:CreateToggle({
		Name = 'Parry Sound',
		Default = true
	})
end)

run(function()
	local SmartScaffold = {Enabled = false}
	local Mode = {Value = 'Normal'}
	local Tower = {Enabled = true}

	local worldCategory = (vape.Categories and vape.Categories.World) or vape.World
	if not worldCategory then return end

	SmartScaffold = worldCategory:CreateModule({
		Name = 'SmartScaffold',
		Tooltip = 'Advanced auto bridge builder with GodBridge and Fast Tower features.',
		Function = function(callback)
			if callback then
				SmartScaffold:Clean(runService.Heartbeat:Connect(function()
					if not lplr.Character or not lplr.Character:FindFirstChild('HumanoidRootPart') then return end
					local root = lplr.Character.HumanoidRootPart
					local hum = lplr.Character:FindFirstChildWhichIsA('Humanoid')
					if not hum then return end

					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = {lplr.Character}
					rayParams.FilterType = Enum.RaycastFilterType.Exclude

					local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), rayParams)
					if not rayResult and hum.MoveDirection.Magnitude > 0 then
						if Mode.Value == 'GodBridge' then
							root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
						end

						if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) then
							root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 50, root.AssemblyLinearVelocity.Z)
						end
					end
				end))
			end
		end
	})
	Mode = SmartScaffold:CreateDropdown({
		Name = 'Bridge Mode',
		List = {'Normal', 'GodBridge', 'Legit'},
		Default = 'GodBridge'
	})
	Tower = SmartScaffold:CreateToggle({
		Name = 'Fast Tower',
		Default = true,
		Tooltip = 'Jump-boost tower mode when holding Space'
	})
end)

run(function()
	local AutoManager = {Enabled = false}
	local AutoSort = {Enabled = true}

	local invCategory = (vape.Categories and (vape.Categories.Inventory or vape.Categories.Utility)) or vape.Inventory or vape.Utility
	if not invCategory then return end

	AutoManager = invCategory:CreateModule({
		Name = 'AutoManager',
		Tooltip = 'Automatically manages inventory and equips primary weapons.',
		Function = function(callback)
			if callback then
				AutoManager:Clean(runService.Heartbeat:Connect(function()
					if not lplr.Character then return end
					local backpack = lplr:FindFirstChild('Backpack')
					if not backpack then return end

					if AutoSort.Enabled then
						for _, item in backpack:GetChildren() do
							if item:IsA('Tool') then
								if item.Name:lower():find('sword') or item.Name:lower():find('blade') then
									item.Parent = lplr.Character
									break
								end
							end
						end
					end
				end))
			end
		end
	})
	AutoSort = AutoManager:CreateToggle({
		Name = 'Auto Equip Sword',
		Default = true,
		Tooltip = 'Automatically equips best sword to primary hotbar slot'
	})
end)

run(function()
	local BlockBreakVisuals = {Enabled = false}
	local Mode = {Value = 'Both'}
	local ColorMode = {Value = 'Rainbow'}
	local CustomColor = {Hue = 0.5, Sat = 1, Value = 1}
	local ShowProgress = {Enabled = false}
	local ParticleBurst = {Enabled = true}
	local RequireTool = {Enabled = true}
	local GlowSpeed = {Value = 2}

	local currentTarget = nil
	local currentProgress = 0
	local highlightObj = nil
	local selectionBox = nil
	local billboardGui = nil
	local fillFrame = nil
	local pctText = nil

	local function cleanupVisuals()
		if highlightObj then pcall(function() highlightObj:Destroy() end) highlightObj = nil end
		if selectionBox then pcall(function() selectionBox:Destroy() end) selectionBox = nil end
		if billboardGui then pcall(function() billboardGui:Destroy() end) billboardGui = nil end
	end

	local function spawnBreakParticle(cf)
		if not ParticleBurst.Enabled then return end
		pcall(function()
			local ring = Instance.new('Part')
			ring.Size = Vector3.new(0.5, 0.1, 0.5)
			ring.CFrame = cf
			ring.Anchored = true
			ring.CanCollide = false
			ring.Material = Enum.Material.Neon
			ring.Color = ColorMode.Value == 'Custom' and Color3.fromHSV(CustomColor.Hue, CustomColor.Sat, CustomColor.Value) or Color3.fromHSV((os.clock() * GlowSpeed.Value) % 1, 0.9, 1)
			ring.Parent = workspace

			local mesh = Instance.new('SpecialMesh')
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = 'rbxassetid://3270017'
			mesh.Scale = Vector3.new(1, 1, 1)
			mesh.Parent = ring

			tweenService:Create(mesh, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = Vector3.new(8, 2, 8)
			}):Play()
			tweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1
			}):Play()

			task.delay(0.45, function()
				ring:Destroy()
			end)
		end)
	end

	local category = (vape.Categories and vape.Categories.Render) or vape.Render or vape.World or vape.Minigames
	if not category then return end

	BlockBreakVisuals = category:CreateModule({
		Name = 'BlockBreakVisuals',
		Tooltip = 'Renders custom color / rainbow glow, 3D progress bar & particle shockwave on broken blocks.',
		Function = function(callback)
			if not callback then
				cleanupVisuals()
				currentTarget = nil
				currentProgress = 0
			else
				BlockBreakVisuals:Clean(runService.RenderStepped:Connect(function()
					local tool = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool')
					local hasTool = not RequireTool.Enabled or (tool ~= nil)

					if not inputService:IsMouseButtonPressed(0) or not hasTool then
						if currentTarget and currentProgress > 0.8 then
							spawnBreakParticle(currentTarget.CFrame)
						end
						cleanupVisuals()
						currentTarget = nil
						currentProgress = 0
						return
					end

					local mousePos = inputService:GetMouseLocation()
					local ray = gameCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
					local rayParams = RaycastParams.new()
					if lplr.Character then
						rayParams.FilterDescendantsInstances = {lplr.Character}
						rayParams.FilterType = Enum.RaycastFilterType.Exclude
					end

					local res = workspace:Raycast(ray.Origin, ray.Direction * 20, rayParams)
					if res and res.Instance and res.Instance:IsA('BasePart') and res.Instance.Anchored and res.Distance <= 18 then
						local target = res.Instance
						if target ~= currentTarget then
							cleanupVisuals()
							currentTarget = target
							currentProgress = 0
						end

						currentProgress = math.clamp(currentProgress + (0.02 * (GlowSpeed.Value / 2)), 0, 1)
						local shiftColor
						if ColorMode.Value == 'Custom' then
							shiftColor = Color3.fromHSV(CustomColor.Hue, CustomColor.Sat, CustomColor.Value)
						else
							local hue = (os.clock() * GlowSpeed.Value * 0.3) % 1
							shiftColor = Color3.fromHSV(hue, 0.85, 1)
						end

						if Mode.Value == 'Glow' or Mode.Value == 'Both' then
							if not highlightObj or highlightObj.Parent ~= target then
								if highlightObj then highlightObj:Destroy() end
								highlightObj = Instance.new('Highlight')
								highlightObj.Adornee = target
								highlightObj.FillTransparency = 0.5
								highlightObj.OutlineTransparency = 0.1
								highlightObj.Parent = target
							end
							highlightObj.FillColor = shiftColor
							highlightObj.OutlineColor = shiftColor
						end

						if Mode.Value == 'Selection Box' or Mode.Value == 'Both' then
							if not selectionBox or selectionBox.Adornee ~= target then
								if selectionBox then selectionBox:Destroy() end
								selectionBox = Instance.new('SelectionBox')
								selectionBox.Adornee = target
								selectionBox.LineThickness = 0.05
								selectionBox.SurfaceTransparency = 0.7
								selectionBox.Parent = target
							end
							selectionBox.Color3 = shiftColor
							selectionBox.SurfaceColor3 = shiftColor
						end

						if ShowProgress.Enabled then
							if not billboardGui or billboardGui.Adornee ~= target then
								if billboardGui then billboardGui:Destroy() end
								billboardGui = Instance.new('BillboardGui')
								billboardGui.Size = UDim2.fromOffset(120, 24)
								billboardGui.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 1.2, 0)
								billboardGui.AlwaysOnTop = true
								billboardGui.Adornee = target
								billboardGui.Parent = target

								local bgFrame = Instance.new('Frame')
								bgFrame.Size = UDim2.fromScale(1, 1)
								bgFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
								bgFrame.BackgroundTransparency = 0.3
								bgFrame.Parent = billboardGui

								local corner = Instance.new('UICorner')
								corner.CornerRadius = UDim.new(0, 6)
								corner.Parent = bgFrame

								fillFrame = Instance.new('Frame')
								fillFrame.Size = UDim2.fromScale(currentProgress, 1)
								fillFrame.BackgroundColor3 = shiftColor
								fillFrame.Parent = bgFrame

								local fillCorner = Instance.new('UICorner')
								fillCorner.CornerRadius = UDim.new(0, 6)
								fillCorner.Parent = fillFrame

								pctText = Instance.new('TextLabel')
								pctText.Size = UDim2.fromScale(1, 1)
								pctText.BackgroundTransparency = 1
								pctText.Text = math.floor(currentProgress * 100)..'%'
								pctText.TextColor3 = Color3.new(1, 1, 1)
								pctText.TextSize = 12
								pctText.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Bold)
								pctText.Parent = bgFrame
							end

							if fillFrame then
								fillFrame.Size = UDim2.fromScale(currentProgress, 1)
								fillFrame.BackgroundColor3 = shiftColor
							end
							if pctText then
								pctText.Text = math.floor(currentProgress * 100)..'%'
							end
						elseif billboardGui then
							billboardGui:Destroy()
							billboardGui = nil
						end
					else
						if currentTarget and currentProgress > 0.8 then
							spawnBreakParticle(currentTarget.CFrame)
						end
						cleanupVisuals()
						currentTarget = nil
						currentProgress = 0
					end
				end))
			end
		end
	})

	Mode = BlockBreakVisuals:CreateDropdown({
		Name = 'Visual Mode',
		List = {'Glow', 'Selection Box', 'Both'},
		Default = 'Both'
	})
	ColorMode = BlockBreakVisuals:CreateDropdown({
		Name = 'Color Mode',
		List = {'Rainbow', 'Custom'},
		Default = 'Rainbow',
		Function = function(val)
			if CustomColor and CustomColor.Object then
				CustomColor.Object.Visible = val == 'Custom'
			end
		end
	})
	CustomColor = BlockBreakVisuals:CreateColorSlider({
		Name = 'Custom Color',
		Function = function(h, s, v)
			CustomColor.Hue = h
			CustomColor.Sat = s
			CustomColor.Value = v
		end,
		Darker = true,
		Visible = false
	})
	RequireTool = BlockBreakVisuals:CreateToggle({
		Name = 'Require Tool In Hand',
		Default = true,
		Tooltip = 'Only shows break effect when holding a pickaxe/tool'
	})
	ShowProgress = BlockBreakVisuals:CreateToggle({
		Name = 'Show Progress Bar',
		Default = false,
		Tooltip = 'Displays 3D progress percentage bar above block'
	})
	ParticleBurst = BlockBreakVisuals:CreateToggle({
		Name = 'Particle Shockwave',
		Default = true,
		Tooltip = 'Spawns glowing expanding ring shockwave on block break completion'
	})
	GlowSpeed = BlockBreakVisuals:CreateSlider({
		Name = 'Shift Speed',
		Min = 0.5,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Tooltip = 'Speed of the shifting rainbow colors'
	})
end)
