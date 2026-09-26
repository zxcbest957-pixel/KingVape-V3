local entitylib = {
	isAlive = false,
	character = {},
	List = {},
	Connections = {},
	PlayerConnections = {},
	EntityThreads = {},
	Running = false,
	Events = setmetatable({}, {
		__index = function(self, ind)
			self[ind] = {
				Connections = {},
				Connect = function(rself, func)
					table.insert(rself.Connections, func)
					return {
						Disconnect = function()
							local rind = table.find(rself.Connections, func)
							if rind then
								table.remove(rself.Connections, rind)
							end
						end
					}
				end,
				Fire = function(rself, ...)
					for _, v in rself.Connections do
						task.spawn(v, ...)
					end
				end,
				Destroy = function(rself)
					table.clear(rself.Connections)
					table.clear(rself)
				end
			}

			return self[ind]
		end
	})
}

local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local lplr = playersService.LocalPlayer
local gameCamera = workspace.CurrentCamera

local function getMousePosition()
	if inputService.TouchEnabled then
		return gameCamera.ViewportSize / 2
	end

	return inputService.GetMouseLocation(inputService)
end

local function loopClean(tbl)
	for i, v in tbl do
		if type(v) == 'table' then
			loopClean(v)
		end

		tbl[i] = nil
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local checktick = tick() + timeout
	local returned
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned or checktick < tick() then break end
		task.wait()
	until false
	return returned
end

entitylib.targetCheck = function(entity)
	if entity.TeamCheck then
		return entity:TeamCheck()
	end
	if entity.NPC then return true end
	if not lplr.Team then return true end
	if not entity.Player.Team then return true end
	if entity.Player.Team ~= lplr.Team then return true end
	return #entity.Player.Team:GetPlayers() == #playersService:GetPlayers()
end

entitylib.getUpdateConnections = function(entity)
	local humanoid = entity.Humanoid
	return {
		humanoid:GetPropertyChangedSignal('Health'),
		humanoid:GetPropertyChangedSignal('MaxHealth')
	}
end

local forcefields = setmetatable({}, {__mode = 'k'})

entitylib.isVulnerable = function(entity)
	if entity.Health <= 0 then
		return false
	end

	local character = entity.Character
	local entry = forcefields[character]
	if not entry then
		entry = {Clock = 0, Value = false}
		forcefields[character] = entry
	end

	local now = os.clock()
	if (now - entry.Clock) >= 0.05 then
		entry.Clock = now
		entry.Value = character.FindFirstChildWhichIsA(character, 'ForceField') ~= nil
	end

	return not entry.Value
end

entitylib.getEntityColor = function(entity)
	entity = entity.Player
	return entity and tostring(entity.TeamColor) ~= 'White' and entity.TeamColor.Color or nil
end

entitylib.IgnoreObject = RaycastParams.new()
entitylib.IgnoreObject.RespectCanCollide = true
local ignorelist = {}
entitylib.Raycast = function(origin, direction, params)
	return workspace:Raycast(origin, direction, params)
end
entitylib.buildIgnore = function(extra)
	table.clear(ignorelist)
	table.insert(ignorelist, gameCamera)
	table.insert(ignorelist, lplr.Character)

	for _, entity in entitylib.List do
		if entity.Targetable then
			table.insert(ignorelist, entity.Character)
		end
	end

	if typeof(extra) == 'table' then
		for _, obj in extra do
			table.insert(ignorelist, obj)
		end
	end

	entitylib.IgnoreObject.FilterDescendantsInstances = ignorelist
	return entitylib.IgnoreObject
end
entitylib.Wallcheck = function(origin, position, ignoreobject)
	if typeof(ignoreobject) ~= 'RaycastParams' then
		ignoreobject = entitylib.buildIgnore(ignoreobject)
	end
	return entitylib.Raycast(origin, position - origin, ignoreobject)
end

entitylib.Priorities = {
	Players = function(v)
		return v.Entity.Player and 0 or 1
	end,
	NPCs = function(v)
		return v.Entity.Player and 1 or 0
	end,
	Closest = function(v)
		return v.Magnitude
	end,
	Farthest = function(v)
		return -v.Magnitude
	end,
	['Lowest health'] = function(v)
		return v.Entity.Health
	end,
	['Highest health'] = function(v)
		return -v.Entity.Health
	end,
	Crosshair = function(v)
		local pos, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Entity.RootPart.Position)
		return vis and (Vector2.new(pos.X, pos.Y) - (gameCamera.ViewportSize / 2)).Magnitude or math.huge
	end
}

local function defaultSort(a, b)
	return a.Magnitude < b.Magnitude
end

local rankedSort, rankedRank
local function rankedCompare(a, b)
	local ranka, rankb = rankedRank(a), rankedRank(b)
	if ranka ~= rankb then
		return ranka < rankb
	end
	return rankedSort(a, b)
end

local scratch, scratchdepth = {}, 0

local function openScratch()
	scratchdepth += 1
	local slot = scratch[scratchdepth]
	if not slot then
		slot = {List = {}, Pool = {}}
		scratch[scratchdepth] = slot
	end
	table.clear(slot.List)
	return slot
end

local function closeScratch(slot)
	table.clear(slot.List)
	scratchdepth -= 1
end

local function addCandidate(slot, entity, magnitude)
	local count = #slot.List + 1
	local entry = slot.Pool[count]
	if not entry then
		entry = {}
		slot.Pool[count] = entry
	end
	entry.Entity = entity
	entry.Magnitude = magnitude
	slot.List[count] = entry
end

entitylib.getSort = function(entitysettings)
	local sort = entitysettings.Sort or defaultSort
	local rank = entitylib.Priorities[entitysettings.Priority]
	if not rank then
		return sort
	end

	rankedSort, rankedRank = sort, rank
	return rankedCompare
end

entitylib.EntityMouse = function(entitysettings)
	if entitylib.isAlive then
		local slot = openScratch()
		local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), slot.List
		for _, entity in entitylib.List do
			if not entitysettings.Players and entity.Player then continue end
			if not entitysettings.NPCs and entity.NPC then continue end
			if not entity.Targetable then continue end
			local position, vis = gameCamera.WorldToViewportPoint(gameCamera, entity[entitysettings.Part].Position)
			if not vis then continue end
			local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
			if mag > entitysettings.Range then continue end
			if entitylib.isVulnerable(entity) then
				addCandidate(slot, entity, entity.Target and -1 or mag)
			end
		end

		table.sort(sortingTable, entitylib.getSort(entitysettings))
		local wallparams = entitysettings.Wallcheck and entitylib.buildIgnore(entitysettings.Wallcheck) or nil
		local found

		for _, v in sortingTable do
			if wallparams then
				if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, wallparams) then continue end
			end
			if entitysettings.Check and not entitysettings.Check(v.Entity) then continue end
			found = v.Entity
			break
		end

		closeScratch(slot)
		table.clear(entitysettings)
		return found
	end
	table.clear(entitysettings)
end

entitylib.EntityPosition = function(entitysettings)
	if entitylib.isAlive then
		local slot = openScratch()
		local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, slot.List
		for _, entity in entitylib.List do
			if not entitysettings.Players and entity.Player then continue end
			if not entitysettings.NPCs and entity.NPC then continue end
			if not entity.Targetable then continue end
			local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
			if mag > entitysettings.Range then continue end
			if entitylib.isVulnerable(entity) then
				addCandidate(slot, entity, entity.Target and -1 or mag)
			end
		end

		table.sort(sortingTable, entitylib.getSort(entitysettings))
		local wallparams = entitysettings.Wallcheck and entitylib.buildIgnore(entitysettings.Wallcheck) or nil
		local found

		for _, v in sortingTable do
			if wallparams then
				if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, wallparams) then continue end
			end
			found = v.Entity
			break
		end

		closeScratch(slot)
		table.clear(entitysettings)
		return found
	end
	table.clear(entitysettings)
end

entitylib.AllPosition = function(entitysettings)
	local returned = {}
	if entitylib.isAlive then
		local slot = openScratch()
		local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, slot.List
		for _, entity in entitylib.List do
			if not entitysettings.Players and entity.Player then continue end
			if not entitysettings.NPCs and entity.NPC then continue end
			if not entity.Targetable then continue end
			local mag = (entity[entitysettings.Part].Position - localPosition).Magnitude
			if mag > entitysettings.Range then continue end
			if entitylib.isVulnerable(entity) then
				addCandidate(slot, entity, entity.Target and -1 or mag)
			end
		end

		table.sort(sortingTable, entitylib.getSort(entitysettings))
		local wallparams = entitysettings.Wallcheck and entitylib.buildIgnore(entitysettings.Wallcheck) or nil
		local limit = entitysettings.Limit or math.huge

		for _, v in sortingTable do
			if wallparams then
				if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, wallparams) then continue end
			end
			table.insert(returned, v.Entity)
			if #returned >= limit then break end
		end
		closeScratch(slot)
	end
	table.clear(entitysettings)
	return returned
end

entitylib.getEntity = function(char)
	for index, entity in entitylib.List do
		if entity.Player == char or entity.Character == char then
			return entity, index
		end
	end
end

entitylib.addEntity = function(char, plr, teamfunc, spawntime)
	if not char then
		return
	end

	entitylib.EntityThreads[char] = task.spawn(function()
		local hum = waitForChildOfType(char, 'Humanoid', 10)
		local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
		local head = char:WaitForChild('Head', 10) or humrootpart

		if hum and humrootpart then
			local entity = {
				Connections = {},
				Character = char,
				Health = hum.Health,
				Head = head,
				Humanoid = hum,
				HumanoidRootPart = humrootpart,
				HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
				MaxHealth = hum.MaxHealth,
				NPC = plr == nil,
				Player = plr,
				RootPart = humrootpart,
				SpawnTime = spawntime or 0,
				TeamCheck = teamfunc
			}

			if plr == lplr then
				entitylib.character = entity
				entitylib.isAlive = true
				entitylib.Events.LocalAdded:Fire(entity)
			else
				entity.Targetable = entitylib.targetCheck(entity)

				for _, connection in entitylib.getUpdateConnections(entity) do
					table.insert(entity.Connections, connection:Connect(function()
						entity.Health = hum.Health
						entity.MaxHealth = hum.MaxHealth
						entitylib.Events.EntityUpdated:Fire(entity)
					end))
				end

				table.insert(entitylib.List, entity)
				entitylib.Events.EntityAdded:Fire(entity)
			end
			--[[table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
				if (part == humrootpart or part == hum or part == head) then
					local found = char:FindFirstChild(part.Name)
					if found then
						if part == humrootpart then
							entity.HumanoidRootPart = found
							entity.RootPart = found
							humrootpart = found
							return
						elseif part == head then
							entity.Head = found
							head = found
							return
						end
					end
					entitylib.removeEntity(char, plr == lplr)
				end
			end))]]
		end

		entitylib.EntityThreads[char] = nil
	end)
end

entitylib.removeEntity = function(char, isLocal)
	if isLocal then
		if entitylib.isAlive then
			entitylib.isAlive = false
			for _, v in entitylib.character.Connections do
				v:Disconnect()
			end
			table.clear(entitylib.character.Connections)
			entitylib.Events.LocalRemoved:Fire(entitylib.character)
			--table.clear(entitylib.character)
		end

		return
	end

	if char then
		if entitylib.EntityThreads[char] then
			task.cancel(entitylib.EntityThreads[char])
			entitylib.EntityThreads[char] = nil
		end

		local entity, index = entitylib.getEntity(char)
		if index then
			for _, v in entity.Connections do
				v:Disconnect()
			end

			table.clear(entity.Connections)
			table.remove(entitylib.List, index)
			entitylib.Events.EntityRemoved:Fire(entity)
		end
	end
end

entitylib.refreshEntity = function(char, plr, spawntime)
	local entity = entitylib.getEntity(plr)
	entitylib.removeEntity(char)
	entitylib.addEntity(char, plr, entity and entity.TeamCheck or nil, spawntime)
end

entitylib.addPlayer = function(plr)
	if plr.Character then
		entitylib.refreshEntity(plr.Character, plr)
	end

	entitylib.PlayerConnections[plr] = {
		plr.CharacterAdded:Connect(function(char)
			entitylib.refreshEntity(char, plr, os.clock() + 0.4)
		end),
		plr.CharacterRemoving:Connect(function(char)
			entitylib.removeEntity(char, plr == lplr)
		end),
		plr:GetPropertyChangedSignal('Team'):Connect(function()
			if plr == lplr then
				local cloned = table.clone(entitylib.List)
				for _, entity in cloned do
					if entity.Targetable ~= entitylib.targetCheck(entity) then
						entitylib.refreshEntity(entity.Character, entity.Player)
					end
				end

				table.clear(cloned)
			else
				local entity = entitylib.getEntity(plr)
				if entity then
					entitylib.refreshEntity(entity.Character, plr)
				end
			end
		end)
	}
end

entitylib.removePlayer = function(plr)
	if entitylib.PlayerConnections[plr] then
		for _, v in entitylib.PlayerConnections[plr] do
			v:Disconnect()
		end

		table.clear(entitylib.PlayerConnections[plr])
		entitylib.PlayerConnections[plr] = nil
	end

	entitylib.removeEntity(plr)
end

entitylib.start = function()
	if entitylib.Running then
		entitylib.stop()
	end

	entitylib.Connections = {
		playersService.PlayerAdded:Connect(function(player)
			entitylib.addPlayer(player)
		end),
		playersService.PlayerRemoving:Connect(function(player)
			entitylib.removePlayer(player)
		end),
		workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
			gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
		end)
	}

	for _, player in playersService:GetPlayers() do
		entitylib.addPlayer(player)
	end

	entitylib.Running = true
end

entitylib.stop = function()
	for _, v in entitylib.Connections do
		v:Disconnect()
	end

	for _, v in entitylib.PlayerConnections do
		for _, v2 in v do
			v2:Disconnect()
		end
		table.clear(v)
	end

	entitylib.removeEntity(nil, true)
	local cloned = table.clone(entitylib.List)
	for _, entity in cloned do
		entitylib.removeEntity(entity.Character)
	end

	for _, thread in entitylib.EntityThreads do
		task.cancel(thread)
	end

	table.clear(entitylib.PlayerConnections)
	table.clear(entitylib.EntityThreads)
	table.clear(entitylib.Connections)
	table.clear(cloned)
	entitylib.Running = false
end

entitylib.kill = function()
	if entitylib.Running then
		entitylib.stop()
	end

	for _, event in entitylib.Events do
		event:Destroy()
	end

	entitylib.IgnoreObject:Destroy()
	loopClean(entitylib)
end

entitylib.refresh = function()
	local cloned = table.clone(entitylib.List)
	for _, entity in cloned do
		entitylib.refreshEntity(entity.Character, entity.Player)
	end
	table.clear(cloned)
end

entitylib.start()

return entitylib