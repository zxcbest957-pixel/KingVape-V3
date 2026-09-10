local vape = shared.vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			local commit = (isfile('catsix/profiles/commit.txt') and readfile('catsix/profiles/commit.txt')) or 'main'
			if not commit or commit == '' then commit = 'main' end
			return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/'..commit..'/'..select(1, path:gsub('catsix/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local buildclock = os.clock()
local run = function(func)
	xpcall(func, function(err)
		task.spawn(error, err)
		vape:CreateNotification('Vape', `A module failed to load: {err}`, 15, 'alert')
	end)

	if os.clock() - buildclock > 0.004 then
		task.wait()
		buildclock = os.clock()
	end
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})
getgenv().vapeEvents = vapeEvents

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local proximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local lightingService = cloneref(game:GetService('Lighting'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontbounds = vape.Libraries.getfontbounds
local getvapeasset = vape.Libraries.getvapeasset

for _, v in {'markKnockback', 'reportHit', 'trackShot', 'expectKnockback'} do
	prediction[v] = prediction[v] or function() end
end

local rankCache = setmetatable({}, {__mode = 'k'})
local store = {
	attackReach = 0,
	lastAttack = 0,
	lastHit = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	swordSpeeds = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	rank = setmetatable({}, {
		__index = function(self, index)
			return {async = function()
				if rankCache[index] then
					return rankCache[index]
				end

				if index then
					local rank = bedwars.Handler:Get('FetchRanks'):Fire('CallServer', {index.UserId})
					if typeof(rank) == 'table' and rank[1] and rank[1].rankDivision then
						rankCache[index] = rank[1].rankDivision
						return rankCache[index]
					end
				end

				return nil
			end}
		end
	}),
	inventories = setmetatable({}, {__mode = 'k'}),
	hitchance = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {},
	ping = {}
}
local Reach = {}
local HitBoxes = {}
local ChargeSpoof = {}
local ChargeRatio = {}
local TrapDisabler = {}
local TrapSnap, TrapMine, TrapTeleport, TrapPortal = {}, {}, {}, {}
local AntiFallPart
local bedwars, sides, oldinvrender = {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getvapeasset('catsix/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end
getgenv().addBlur = addBlur

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, indexes, connections = {}, {}, {}

	for _, v in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(v):Connect(function(obj)
			if customadd then
				customadd(objs, obj, v)
				return
			end
			objs[#objs + 1] = obj
			indexes[obj] = #objs
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(v):Connect(function(obj)
			if customremove then
				customremove(objs, obj, v)
				return
			end
			if customadd then
				local index = table.find(objs, obj)
				if index then
					table.remove(objs, index)
				end
				return
			end

			local index = indexes[obj]
			if index then
				local size = #objs
				local last = objs[size]
				objs[index] = last
				indexes[last] = index
				objs[size] = nil
				indexes[obj] = nil
			end
		end))

		for _, v2 in collectionService:GetTagged(v) do
			if customadd then
				customadd(objs, v2, v)
				continue
			end
			objs[#objs + 1] = v2
			indexes[v2] = #objs
		end
	end

	local function cleanFunc(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(indexes)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end
getgenv().collection = collection

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, v in store.inventory.inventory.items do
		local meta = v and bedwars.ItemMeta[v.itemType] or {}
		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)
			if newmag > mag then
				closest, mag = v, newmag
			end
		end
	end

	return closest
end
getgenv().getBestArmor = getBestArmor

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for i, v in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[v.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = v, i, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end
getgenv().getBow = getBow

local function matchesList(list, names)
	for _, v in list do
		local needle = (tostring(v):lower():gsub('[_%s]+', ' '))
		if #needle > 0 then
			for _, v2 in names do
				if v2 then
					v2 = (tostring(v2):lower():gsub('[_%s]+', ' '))
					if v2 == needle or (' '..v2):find(' '..needle, 1, true) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function getMageSource(itemType)
	if itemType ~= 'wizard_stick' then return nil end

	local util = bedwars.MageKitUtil
	local elements = util and util.MageElementMeta
	if not elements then return nil end

	local chosen = elements.BASE
	local suc, unlocked = pcall(util.getUnlockedMageElements, lplr)
	if suc and type(unlocked) == 'table' then
		for i, v in unlocked do
			local element = elements[v] or elements[i]
			if element and element.projectileSource then
				chosen = element
			end
		end
	end

	return chosen and chosen.projectileSource
end

local sophiaStaffs = {'frost_staff_3', 'frost_staff_2', 'frost_staff_1'}
local nextSophiaSwap = 0

local function getSophiaSource(itemType)
	if not table.find(sophiaStaffs, itemType) then return nil end

	local controller = bedwars.FrostyGunController
	if not controller then return nil end

	if controller.projectileMode ~= bedwars.FrostyGunMode.PROJECTILE then
		if tick() >= nextSophiaSwap and bedwars.AbilityController:canUseAbility('frosty_gun_swap', {disableBlockedAbilityAlert = true}) then
			nextSophiaSwap = tick() + 1
			bedwars.AbilityController:useAbility('frosty_gun_swap')
		end
		return nil
	end

	local meta = bedwars.ItemMeta[itemType]
	return meta and meta.projectileSource or nil
end

local function getWhimSource(itemType)
	if itemType ~= 'mage_spellbook' then return nil end

	local util = bedwars.MageKitUtil
	local elements = util and util.MageElementMeta
	if not elements then return nil end

	local element = bedwars.BalanceFile.MAGE_ELEMENT_CYCLE[(lplr:GetAttribute('MageElementIndex') or 0) + 1]
	local suc, unlocked = pcall(util.getUnlockedMageElements, lplr)
	if not element or not suc or type(unlocked) ~= 'table' or table.find(unlocked, element) == nil then
		element = 'BASE'
	end

	local meta = elements[element]
	return meta and meta.projectileSource or nil
end

local nazarWeapons = {'life_bow', 'life_crossbow', 'life_headhunter'}

local function getNazarSource(itemType)
	if not table.find(nazarWeapons, itemType) then return nil end

	local meta = bedwars.ItemMeta[itemType]
	return meta and meta.projectileSource or nil
end

local function getProjectiles(whitelist, sophia, whim, nazar)
	local items = {}
	for _, v in store.inventory.inventory.items do
		local meta = bedwars.ItemMeta[v.itemType]
		local kit = (sophia and getSophiaSource(v.itemType)) or (whim and getWhimSource(v.itemType)) or (nazar and getNazarSource(v.itemType)) or nil
		local proj = kit or (meta and (meta.projectileSource or getMageSource(v.itemType)))
		if proj then
			local ammo
			if proj.ammoItemTypes and #proj.ammoItemTypes > 0 then
				for _, v2 in store.inventory.inventory.items do
					if table.find(proj.ammoItemTypes, v2.itemType) then
						ammo = v2.itemType
						break
					end
				end
			else
				ammo = v.itemType
			end

			if ammo and (kit or not whitelist or matchesList(whitelist, {ammo, v.itemType, meta.displayName})) then
				table.insert(items, {
					v,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
	end

	return items
end
getgenv().getProjectiles = getProjectiles

local function getFacingEntity(entitysettings)
	if not entitylib.isAlive then
		return nil
	end

	local rootpart = entitylib.character.RootPart
	local origin = entitysettings.Origin or rootpart.Position
	local facing = rootpart.CFrame.LookVector * Vector3.new(1, 0, 1)
	local cone = math.rad((entitysettings.Angle or 120) / 2)
	entitysettings.Angle = nil
	entitysettings.Origin = origin

	for _, v in entitylib.AllPosition(entitysettings) do
		local delta = (v.RootPart.Position - origin) * Vector3.new(1, 0, 1)
		if facing.Magnitude == 0 or delta.Magnitude == 0 or math.acos(math.clamp(facing.Unit:Dot(delta.Unit), -1, 1)) <= cone then
			return v
		end
	end
	return nil
end
getgenv().getFacingEntity = getFacingEntity

local function solveProjectile(origin, speed, gravity, target)
	return prediction.SolveTrajectory(origin, speed, gravity, target.RootPart.Position, target.RootPart.AssemblyLinearVelocity, workspace.Gravity, target.HipHeight, target.Jumping and 42.6 or nil, nil, target.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(target.RootPart.AssemblyLinearVelocity.Y) > 0.01, target.RootPart.Position, target.RootPart, nil, true)
end

local function fireProjectile(item, ammo, projectile, target)
	local meta = bedwars.ProjectileMeta[projectile]
	if not meta then return false end

	local origin = entitylib.character.RootPart.Position
	local speed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
	local calc = solveProjectile(origin, speed, gravity, target)
	if not calc then return false end

	local shootPosition = (CFrame.new(origin, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
	local aim = solveProjectile(shootPosition, speed, gravity, target) or calc
	local velocity, id = CFrame.lookAt(shootPosition, aim).LookVector * speed, httpService:GenerateGUID(true)
	bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
		item.tool,
		ammo,
		projectile,
		shootPosition,
		origin,
		velocity,
		id,
		{
			drawDurationSeconds = 1,
			shotId = httpService:GenerateGUID(false)
		},
		workspace:GetServerTimeNow() - 0.045
	):andThen(function(res)
		if res then
			res.Parent = replicatedStorage
		end
	end)
	prediction.trackShot(target.RootPart)
	return true
end
getgenv().fireProjectile = fireProjectile

local function getItem(itemName, inv, find)
	for i, v in (inv or store.inventory.inventory.items) do
		if v.itemType == itemName or (find and v.itemType:find(itemName)) then
			return v, i
		end
	end
	return nil
end
getgenv().getItem = getItem

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage, bestSwordRange = nil, nil, -1, -1
	for i, v in store.inventory.inventory.items do
		local itemMeta = bedwars.ItemMeta[v.itemType]
		local swordMeta = itemMeta and itemMeta.sword or nil
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			local swordRange = swordMeta.attackRange or store.swordDistance or 0
			if swordDamage > bestSwordDamage or (swordDamage == bestSwordDamage and swordRange > bestSwordRange) then
				bestSword, bestSwordSlot, bestSwordDamage, bestSwordRange = v, i, swordDamage, swordRange
			end
		end
	end
	return bestSword, bestSwordSlot
end
getgenv().getSword = getSword

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for i, v in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[v.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = v, i, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end
getgenv().getTool = getTool

local function getWool()
	for _, v in store.inventory.inventory.items do
		if v.itemType:find('wool') then
			return v.itemType, v.amount
		end
	end
end
getgenv().getWool = getWool

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end
getgenv().getStrength = getStrength

local function isCasting()
	local casting = lplr:GetAttribute('IsCasting')
	return casting and casting ~= 0 and casting ~= ''
end
getgenv().isCasting = isCasting

local function canSwing()
	if bedwars.SwordController:getSwordSwingDisabled() or isCasting() then
		return false
	end

	local itemmeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
	return itemmeta and itemmeta.sword ~= nil and itemmeta.sword.chargedAttack == nil
end
getgenv().canSwing = canSwing

local function canPlace()
	return not bedwars.BlockPlacementController.disabled and not isCasting()
end
getgenv().canPlace = canPlace

store.lastInput = tick()
local function markInput(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement or input.Delta.Magnitude > 0 then
		store.lastInput = tick()
	end
end
vape:Clean(inputService.InputBegan:Connect(markInput))
vape:Clean(inputService.InputChanged:Connect(markInput))

local function isAfk()
	return (tick() - store.lastInput) >= 30
end
getgenv().isAfk = isAfk

local function getReach(tool)
	local itemmeta = tool and bedwars.ItemMeta[tool.Name]
	return itemmeta and itemmeta.sword and itemmeta.sword.attackRange or store.swordDistance
end
getgenv().getReach = getReach

local function getSwordSpeed(tool)
	local itemmeta = tool and bedwars.ItemMeta[tool.Name]
	return store.swordSpeeds[tool and tool.Name] or (itemmeta and itemmeta.sword and itemmeta.sword.attackSpeed) or 0.3
end
getgenv().getSwordSpeed = getSwordSpeed

local targetlimbs = {
	Torso = {'UpperTorso', 'LowerTorso'},
	['Left arm'] = {'LeftUpperArm', 'LeftLowerArm', 'LeftHand'},
	['Right arm'] = {'RightUpperArm', 'RightLowerArm', 'RightHand'},
	['Left leg'] = {'LeftUpperLeg', 'LeftLowerLeg', 'LeftFoot'},
	['Right leg'] = {'RightUpperLeg', 'RightLowerLeg', 'RightFoot'}
}
local limborder = {'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg'}
local partlist = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random'}
getgenv().partlist = partlist

local randomlimb = setmetatable({}, {__mode = 'k'})

local function getTargetPart(entity, mode)
	if mode == 'Random' and entity.Character then
		local pick = randomlimb[entity.Character]
		if not pick or tick() > pick.Clock then
			pick = {Value = limborder[math.random(1, #limborder)], Clock = tick() + 1}
			randomlimb[entity.Character] = pick
		end
		mode = pick.Value
	end

	if mode == 'Head' then
		return (entity.Character and entity.Character:FindFirstChild('Head')) or entity.Head or entity.RootPart
	end

	local limbs = targetlimbs[mode]
	if limbs and entity.Character then
		for _, v in limbs do
			local part = entity.Character:FindFirstChild(v)
			if part then
				return part
			end
		end
	end

	return entity.RootPart
end
getgenv().getTargetPart = getTargetPart

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end
getgenv().getPlacedBlock = getPlacedBlock

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end
getgenv().getBlocksInPoints = getBlocksInPoints

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))
	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end
getgenv().getNearGround = getNearGround

local function getShieldAttribute(char)
	return math.max(char:GetAttribute('TotalShield') or 0, 0)
end
getgenv().getShieldAttribute = getShieldAttribute

local function markKnockback(damageTable)
	local char = damageTable.entityInstance
	local multiplier = damageTable.knockbackMultiplier
	if typeof(char) ~= 'Instance' or (multiplier and multiplier.disabled) then return end

	local root = char:IsA('Model') and char.PrimaryPart or char:IsA('BasePart') and char or nil
	local from = damageTable.fromPosition
	local impulse
	if root and from then
		local direction = bedwars.KnockbackUtil.getDirection(root.Position, from)
		if direction.Magnitude > 0 then
			impulse = bedwars.KnockbackUtil.calculateKnockbackVelocity(direction, 1, multiplier)
		end
	end

	prediction.markKnockback(char, multiplier, impulse)
end

local function expectKnockback(root, flight, from, multiplier)
	if typeof(root) ~= 'Instance' or not flight or not from then return end
	if multiplier and multiplier.disabled then return end

	local direction = bedwars.KnockbackUtil.getDirection(root.Position, from)
	if direction.Magnitude <= 0 then return end

	prediction.expectKnockback(root, workspace:GetServerTimeNow() + flight, bedwars.KnockbackUtil.calculateKnockbackVelocity(direction, 1, multiplier), multiplier)
end
getgenv().expectKnockback = expectKnockback

local function scanProjectile(origin, velocity, projectileType, shooter)
	if not entitylib.isAlive then return end

	local meta = bedwars.ProjectileMeta[projectileType]
	local drop = Vector3.new(0, -(meta and meta.gravitationalAcceleration or 196.2), 0)

	for _, v in entitylib.List do
		if v.Character == shooter then continue end

		local root, hit = v.RootPart
		local rootVelocity = root.AssemblyLinearVelocity
		for step = 1, 40 do
			local flight = step * 0.05
			local point = origin + velocity * flight + drop * (0.5 * flight * flight)
			if (point - (root.Position + rootVelocity * flight)).Magnitude <= v.HipHeight then
				hit = flight
				break
			end
		end

		if hit then
			expectKnockback(root, hit, origin, meta and meta.knockback)
		end
	end
end
getgenv().scanProjectile = scanProjectile

local function reportProjectileHit(damageTable)
	local char = damageTable.entityInstance
	local from = damageTable.fromEntity
	if (from ~= lplr.Character and from ~= lplr) or typeof(char) ~= 'Instance' then return end

	local root = char:IsA('Model') and char.PrimaryPart or char:IsA('BasePart') and char or nil
	if root then
		prediction.reportHit(root)
	end
end

local knockbackSpeed, knockbackBoost = 0, tick()
local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()
	for i in modifiers do
		local val = i.constantSpeedMultiplier and i.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for i in modifiers do
		multi += math.max((i.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return (20 + (knockbackBoost > tick() and knockbackSpeed or 0)) * (multi + 1)
end
getgenv().getSpeed = getSpeed

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end
getgenv().getTableSize = getTableSize

local function getHotbar(tool)
	for i, v in (store.inventory.hotbar or {}) do
		if v.item and v.item.tool == tool then
			return i - 1
		end
	end
	return nil
end
getgenv().getHotbar = getHotbar

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end
getgenv().hotbarSwitch = hotbarSwitch

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

local function notif(...)
	return vape:CreateNotification(...)
end
getgenv().notif = notif

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end
getgenv().removeTags = removeTags

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end
getgenv().roundPos = roundPos

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Handler:Get('SetInvItem'):Fire('CallServerAsync', {hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end
getgenv().switchItem = switchItem

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, setmetatable({}, {__mode = 'k'})
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = next(frictionTable) ~= nil
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return (a.Entity.Character:GetAttribute('LastDamageTakenTime') or 0) < (b.Entity.Character:GetAttribute('LastDamageTakenTime') or 0)
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKits')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKits')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local direction = (a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)
		local direction2 = (b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)
		local angle = direction.Magnitude > 0 and math.acos(math.clamp(localfacing:Dot(direction.Unit), -1, 1)) or 0
		local angle2 = direction2.Magnitude > 0 and math.acos(math.clamp(localfacing:Dot(direction2.Unit), -1, 1)) or 0
		return angle < angle2
	end,
	Mouse = function(a, b)
		local mouse = lplr:GetMouse()
		local origin = Vector2.new(mouse.X, mouse.Y)

		local posa, visa = gameCamera:WorldToScreenPoint(a.Entity.RootPart.Position)
		local posb, visb = gameCamera:WorldToScreenPoint(b.Entity.RootPart.Position)
		local dista = visa and (Vector2.new(posa.X, posa.Y) - origin).Magnitude or math.huge
		local distb = visb and (Vector2.new(posb.X, posb.Y) - origin).Magnitude or math.huge
		return (dista == dista and dista or math.huge) < (distb == distb and distb or math.huge)
	end
}
getgenv().sortmethods = sortmethods

local sortlist = {}
for i in sortmethods do
	table.insert(sortlist, i)
end
table.sort(sortlist)
getgenv().sortlist = sortlist

local motion = setmetatable({}, {__mode = 'k'})

local function getHitChance(ent, flight)
	if not flight or flight ~= flight or flight <= 0 then return 0 end

	local root = ent.RootPart
	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local sample = motion[root]
	if not sample then
		sample = {velocity = velocity, clock = os.clock(), accel = 0, speed = velocity.Magnitude}
		motion[root] = sample
	end

	local step = os.clock() - sample.clock
	if step >= 0.05 then
		local blend = math.min(step * 5, 1)
		sample.accel += (((velocity - sample.velocity).Magnitude / step) - sample.accel) * blend
		sample.speed += (velocity.Magnitude - sample.speed) * blend
		sample.velocity, sample.clock = velocity, os.clock()
	end

	local drift = math.max(sample.speed, velocity.Magnitude) * math.min(flight, 0.4) * math.clamp(sample.accel / 120, 0, 1)
	return 1 / (1 + ((drift / 3) ^ 2))
end
getgenv().getHitChance = getHitChance

local getBlockHits
local breakmethods = {
	Health = function(a, b)
		return getBlockHits(a, b)
	end,
	Distance = function(a, b)
		local pos = (entitylib.isAlive and (entitylib.character.RootPart.Position - Vector3.new(0, 1, 0)) or Vector3.zero)
		return (pos - Vector3.new(a.Position.X, pos.Y, a.Position.Z)).Magnitude + getBlockHits(a, b) * 0.01
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') and not ent:HasTag('trainingRoomDummy') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, v in collectionService:GetTagged('entity') do
				customEntity(v)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = char:FindFirstChildOfClass('Humanoid') or {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
					table.insert(entity.Connections, char.AttributeChanged:Connect(function(attr)
						if attr == 'Health' or attr == 'MaxHealth' or attr:find('Shield') then
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
						end
					end))
					for _, v in {hum:GetPropertyChangedSignal('HipHeight'), humrootpart:GetPropertyChangedSignal('Size')} do
						table.insert(entity.Connections, v:Connect(function()
							entity.HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0)
						end))
					end
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entity.HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0)
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKits'))
		end

		table.insert(tab, char:GetAttributeChangedSignal('TotalShield'))

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

local require, debug, cheatenginelib = require, debug, nil
run(function()
	getgenv().canDebug = not table.find({'Solara', 'Xeno'}, ({identifyexecutor()})[1]) and true or false
	if not canDebug then
		cheatenginelib = loadstring(downloadFile('catsix/libraries/cheatengine.lua'), 'cheatengine')(vape, vapeEvents, entitylib)
		require = function(v)
			return cheatenginelib[({v:GetFullName():gsub(lplr.Name, 'PlayerTemplate')})[1]]:await()
		end
		debug = setmetatable({getproto = function() return function() end end}, {
			__index = function(self, index)
				self[index] = function() end
				return self[index]
			end
		})
	end
end)

local calculatePath
run(function()
	local Client, OldGet, OldBreak, OldHit, OldWallcheck
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			if not canDebug then
				return require(replicatedStorage['rbxts_include']['node_modules']['@easy-games'].knit.src).KnitClient
			end
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit and Knit then break end
		task.wait()
	until KnitInit and Knit

	if canDebug and not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local ItemMetaModule = require(replicatedStorage.TS.item['item-meta'])
	local TeamUpgradeModule = require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta'])
	local Remotes = require(replicatedStorage.TS.remotes).default
	Client = Remotes.Client
	OldGet = Client.Get

	local RemoteHandler = {}
	RemoteHandler.CachedRemotes = {}
	RemoteHandler.__index = RemoteHandler

	local RemoteDefinitionConstruct, RemotesInConstruct
	if canDebug then
		RemoteDefinitionConstruct, RemotesInConstruct = next(getupvalue(getrawmetatable(Remotes.Server).Get, 1))
	end

	local GlobalMiddleware = RemoteDefinitionConstruct and getupvalue(RemoteDefinitionConstruct.globalMiddleware[2], 1)
	if canDebug and (not GlobalMiddleware or typeof(GlobalMiddleware) ~= 'table') then
		notif('KingVape', 'Failed to load ratelimits, report this to a developer.', 30, 'alert')
	end

	function RemoteHandler.Get(self, RemoteID)
		if RemoteHandler.CachedRemotes[RemoteID] then
			return RemoteHandler.CachedRemotes[RemoteID]
		end

		local Remote = {}
		setmetatable(Remote, RemoteHandler)

		Remote.ID = RemoteID
		Remote.RequestsInLastMinute = 0
		Remote.MaxRequestsPerMinute = Remote:GetRateLimit()
		Remote.LastRateLimitReset = 0

		local Success, AttempedRemote = pcall(Client.Get, Client, Remote.ID)
		Remote.Success = Success
		Remote.Remote = AttempedRemote

		if not Success or not Remote.Remote then
			notif('KingVape', `Tried to Get remote {Remote.ID}, remote is invalid`, 15, 'alert')
			Remote.Remote = nil
		end

		RemoteHandler.CachedRemotes[RemoteID] = Remote
		return Remote
	end

	function RemoteHandler:Fire(Method, ...)
		local Remote = self.Remote
		if not self.Success or not Remote then
			return {andThen = function() end}
		end

		if (os.clock() - self.LastRateLimitReset) >= 60 then
			self:ResetRateLimit()
		end

		if self:GetCurrentRequests() >= self:GetRateLimit() then
			return {andThen = function() end}
		end

		self:IncrementRequests()
		local CallingFunction = (Method and Remote[Method]) or (Remote.CallServer or Remote.CallServerAsync or Remote.SendToServer)
		if CallingFunction then
			return CallingFunction(Remote, ...)
		end

		return
	end

	function RemoteHandler:ResetRateLimit()
		self.RequestsInLastMinute = 0
		self.LastRateLimitReset = os.clock()
	end

	function RemoteHandler:GetCurrentRequests()
		return self.RequestsInLastMinute
	end

	function RemoteHandler:IncrementRequests()
		self.RequestsInLastMinute = self.RequestsInLastMinute + 1
	end

	function RemoteHandler:GetRateLimit()
		local RemoteName = self.ID
		if self.CachedRemotes[RemoteName] then
			return self.CachedRemotes[RemoteName].MaxRequestsPerMinute
		end

		if not GlobalMiddleware then
			local CachedLimits = cheatenginelib and cheatenginelib.RateLimits
			return CachedLimits and CachedLimits[RemoteName] or 300
		end

		local GlobalFind = GlobalMiddleware[RemoteName]
		local RateLimitValue = (typeof(GlobalFind) ~= 'number' and 300) or GlobalFind

		if not GlobalFind then
			local TargetRemote = RemotesInConstruct[RemoteName]
			local RemoteRateLimit = (TargetRemote and TargetRemote.ServerMiddleware)
			if RemoteRateLimit and typeof(RemoteRateLimit) == 'table' then
				for _, v in RemoteRateLimit do
					if typeof(v) == 'function' and (#getupvalues(v) >= 6 and tostring(getupvalue(v, 6)):find('Request limit')) then
						local Value = getupvalue(v, 3)
						RateLimitValue = (typeof(Value) == 'number' and Value) or RateLimitValue
						break
					end
				end
			end
		end

		return RateLimitValue
	end

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AbilityIndicatorUtil = require(replicatedStorage.TS.games.bedwars.items['ability-indicator']['ability-indicator-util']).AbilityIndicatorUtil,
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil,
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BalanceFile = require(replicatedStorage.TS.balance['balance-file']).BalanceFile,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedDefenseMeta = require(replicatedStorage.TS['no-build']['bed-defense-meta']).BedDefenseMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlackMarketeerBalance = require(replicatedStorage.TS.balance['black-marketeer-balance']).BlackMarketeerBalance,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8) or (cheatenginelib and cheatenginelib.BowConstantsTable),
		BlockSelector = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelector,
		BountyHunterUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.bountyhunter['bounty-hunter-util']).BountyHunterUtil,
		BlockSelectorMode = require(replicatedStorage.rbxts_include.node_modules['@easy-games']['block-engine'].out.client.select['block-selector']).BlockSelectorMode,
		ArmorTrimColor = require(replicatedStorage.TS['armor-trim']['armor-trim-colors']).ArmorTrimColor,
		ArmorTrimEffectMeta = require(replicatedStorage.TS['armor-trim']['armor-trim-effect-meta']).ArmorTrimEffectMeta,
		ArmorTrimEffectRankMeta = require(replicatedStorage.TS['armor-trim']['armor-trim-rank']).ArmorTrimEffectRankMeta,
		ArmorTrimEffectType = require(replicatedStorage.TS['armor-trim']['armor-trim-effect-type']).ArmorTrimEffectType,
		ArmorTrimMeta = require(replicatedStorage.TS['armor-trim']['armor-trim-meta']).ArmorTrimMeta,
		ArmorTrimType = require(replicatedStorage.TS['armor-trim']['armor-trim-type']).ArmorTrimType,
		ChargeState = require(replicatedStorage.TS.combat['charge-state']).ChargeState,
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		ConquerorBalance = require(replicatedStorage.TS.balance['conqueror-balance']).ConquerorBalance,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		EmoteDisplayMeta = require(replicatedStorage.TS.locker.emote['emote-display-meta']).EmoteDisplayMeta,
		EmoteMeta = require(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta,
		EnchantMeta = require(replicatedStorage.TS.enchant['enchant-meta']).EnchantMeta,
		FishermanUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.fisherman['fisherman-util']).FishermanUtil,
		FrostyGunMode = require(replicatedStorage.TS.games.bedwars.kit.kits['frosty-gun']['frosty-gun-util']).FrostyGunMode,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		GamePlayerUtil = require(replicatedStorage.TS.player['player-util']).GamePlayerUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getItemSkinMeta = require(replicatedStorage.TS.games.bedwars['item-skin']['item-skin-meta']).getItemSkinMeta,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		Handler = RemoteHandler,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ImageList = require(replicatedStorage.TS.image['image-id']).BedwarsImageId,
		ItemMeta = debug.getupvalue(ItemMetaModule.getItemMeta, 1) or ItemMetaModule.items,
		IsItemClaw = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-util']).summoner_isItemClaw,
		ItemSkinType = require(replicatedStorage.TS.games.bedwars['item-skin']['item-skin-types']).ItemSkinType,
		JadeBalance = require(replicatedStorage.TS.balance['jade-balance']).JadeBalance,
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		LumenBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.lumen['lumen-balance']).LumenBalance,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		MelodyKitBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.melody['melody-kit-balance']).MelodyKitBalance,
		NametagController = Knit.Controllers.NametagController,
		NoBuildUtil = require(replicatedStorage.TS['no-build']['no-build-util']).NoBuildUtil,
		NotificationController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/notification-controller@NotificationController'),
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		RankMeta = require(replicatedStorage.TS.rank['rank-meta']).RankMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		scaleTool = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['scale-model'].out).scaleTool,
		StatusEffectUtil = require(replicatedStorage.TS['status-effect']['status-effect-util']).StatusEffectUtil,
		StatusEffectMeta = require(replicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType,
		SummonerKitBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance,
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SettingsMeta = require(replicatedStorage.TS.settings['settings-meta']).SettingMeta,
		SharedConstants = require(replicatedStorage.TS['shared-constants']).CpsConstants,
		SoulBrokerConstants = require(replicatedStorage.TS.games.bedwars.kit.kits['soul-broker']['soul-broker-constants']).SoulBrokerConstants,
		SorcererBalance = require(replicatedStorage.TS.balance['sorcerer-balance']).SorcererBalance,
		SorcererTierMeta = require(replicatedStorage.TS.balance['sorcerer-balance']).SorcererTierMeta,
		SummonerUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-util']),
		AudioManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).AudioManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		SyncEvents = require(lplr.PlayerScripts.TS['client-sync-events']).ClientSyncEvents,
		TeamUpgradeMeta = debug.getupvalue(TeamUpgradeModule.getTeamUpgradeMetaForQueue, 2) or (cheatenginelib and cheatenginelib.TeamUpgradeMeta),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		VoidRegentBalance = require(replicatedStorage.TS.balance['void-regent-balance']).VoidRegentBalance,
		VoidHunterBalance = require(replicatedStorage.TS.games.bedwars.kit.kits['void-hunter']['void-hunter-kit-balance']).VoidHunterKitBalance,
		WarlockBalance = require(replicatedStorage.TS.balance['balance-file']).WarlockBalance,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		WizardUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.wizard['wizard-util']).WizardUtil,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})
	store.enchants = setmetatable({}, {
		__index = function(self, plr)
			return {
				async = function()
					if plr and plr.Character then
						for i in plr.Character:GetAttributes() do
							if i:find('StatusEffect_') and not i:find('_stacks') then
								local name = bedwars.StatusEffectMeta[({i:gsub('StatusEffect_', '')})[1]]
								if bedwars.StatusEffectMeta[name] then
									name = bedwars.StatusEffectMeta[name]
									for num = 1, 3 do
										name = name:gsub(`_{num}`, '')
									end

									if bedwars.EnchantMeta[name] then
										return bedwars.EnchantMeta[name].image
									end
								end
							end
						end
					end
					return nil
				end,
			}
		end
	})
	getgenv().store = store
	getgenv().bedwars = bedwars

	entitylib.Raycast = function(origin, direction, params)
		return bedwars.QueryUtil:raycast(origin, direction, params)
	end
	prediction.Raycast = entitylib.Raycast

	OldWallcheck = entitylib.Wallcheck
	local wallcheckParams = RaycastParams.new()
	wallcheckParams.FilterType = Enum.RaycastFilterType.Exclude

	entitylib.Wallcheck = function(origin, position, ignoreobject, entity)
		local character = entity and entity.Character
		local selfcharacter = lplr.Character
		local selfroot = selfcharacter and selfcharacter.PrimaryPart
		local targetroot = character and character.PrimaryPart
		if not selfroot or not targetroot then
			return OldWallcheck(origin, position, ignoreobject)
		end

		local humanoid = selfcharacter:FindFirstChildWhichIsA('Humanoid')
		local targethumanoid = character:FindFirstChildWhichIsA('Humanoid')
		local scale = humanoid and humanoid:FindFirstChild('BodyHeightScale')
		local height = Vector3.new(0, 5 * (scale and scale.Value or 1), 0)
		local selffeet = selfroot.Position - Vector3.new(0, (humanoid and humanoid.HipHeight or 0) + (selfroot.Size.Y / 2), 0)
		local targetfeet = targetroot.Position - Vector3.new(0, (targethumanoid and targethumanoid.HipHeight or 0) + (targetroot.Size.Y / 2), 0)
		local selfhead, targethead = selffeet + height, targetfeet + height
		local selfmid, targetmid = (selffeet + selfhead) / 2, (targetfeet + targethead) / 2

		local filter = {selfcharacter, character}
		for _, v in collectionService:GetTagged('DontBlockSwordRaycast') do
			table.insert(filter, v)
		end
		if typeof(ignoreobject) == 'table' then
			for _, v in ignoreobject do
				table.insert(filter, v)
			end
		end
		wallcheckParams.FilterDescendantsInstances = filter

		return (entitylib.Raycast(selffeet, targetfeet - selffeet, wallcheckParams) or entitylib.Raycast(targetfeet, selffeet - targetfeet, wallcheckParams)) and (entitylib.Raycast(selfhead, targethead - selfhead, wallcheckParams) or entitylib.Raycast(targethead, selfhead - targethead, wallcheckParams)) and (entitylib.Raycast(selfmid, targetmid - selfmid, wallcheckParams) or entitylib.Raycast(targetmid, selfmid - targetmid, wallcheckParams)) or nil
	end

	OldBreak = bedwars.BlockController.isBlockBreakable
	OldHit = bedwars.BlockBreaker.hitBlock

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == 'SwordHit' then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						local delta = targetpos - selfpos
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += delta.Magnitude > 0.001 and delta.Unit * math.max(delta.Magnitude - (getReach(attackTable.weapon) - 0.001), 0) or Vector3.zero
					end

					if ChargeSpoof.Enabled and attackTable.chargedAttack then
						attackTable.chargedAttack.chargeRatio = math.max(attackTable.chargedAttack.chargeRatio or 0, ChargeRatio.Value / 100)
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif TrapDisabler.Enabled and (remoteName == 'StepOnSnapTrap' and TrapSnap.Enabled or remoteName == 'TriggerInvisibleLandmine' and TrapMine.Enabled or remoteName == 'StepOnTeleportBlock' and TrapTeleport.Enabled or remoteName == 'StepOnVoidPortal' and TrapPortal.Enabled) then
			return {SendToServer = function() end}
		end

		return call
	end


	bedwars.BlockBreaker.hitBlock = function(self, ...)
		store.lastHit = tick()
		return OldHit(self, ...)
	end

	local pathcache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.swordDistance = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	getBlockHits = function(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	calculatePath = function(target, blockpos, solidonly, breakmethod)
		local origin = entitylib.character.RootPart.Position
		local cell = bedwars.BlockController:getBlockPosition(origin)
		local key = `{blockpos.X},{blockpos.Y},{blockpos.Z}|{solidonly and 1 or 0}|{breakmethod == breakmethods.Distance and 1 or 0}`
		local cached = pathcache[key]
		if cached and cached.cell == cell then
			return cached.pos, cached.cost, cached.path
		end

		local routes = {}
		local function isOpen(open)
			if routes[open] ~= nil then
				return routes[open]
			end
			local queue, seen, reached = {open}, {[open] = true}, true

			for _ = 1, 400 do
				local current = table.remove(queue)
				if not current then
					reached = false
					break
				end
				if (current - blockpos).Magnitude > 15 then break end

				for _, v in sides do
					v = current + v
					if seen[v] or getPlacedBlock(v) then continue end
					seen[v] = true
					table.insert(queue, v)
				end
			end

			for i in seen do
				routes[i] = reached
			end
			return reached
		end

		local function boundary(index, component, delta)
			if delta == 0 then
				return 0, math.huge, math.huge
			end
			local step = delta > 0 and 1 or -1
			return step, ((((index + (step * 0.5)) * 3) - component) / delta), (3 / math.abs(delta))
		end

		local function trace(from, aim)
			local start, direction = bedwars.BlockController:getBlockPosition(from), aim - from
			local x, y, z = start.X, start.Y, start.Z
			local stepx, nextx, deltax = boundary(x, from.X, direction.X)
			local stepy, nexty, deltay = boundary(y, from.Y, direction.Y)
			local stepz, nextz, deltaz = boundary(z, from.Z, direction.Z)

			for _ = 1, 100 do
				if nextx > 1 and nexty > 1 and nextz > 1 then break end

				if nextx <= nexty and nextx <= nextz then
					x, nextx = x + stepx, nextx + deltax
				elseif nexty <= nextz then
					y, nexty = y + stepy, nexty + deltay
				else
					z, nextz = z + stepz, nextz + deltaz
				end

				if getPlacedBlock(Vector3.new(x, y, z) * 3) then
					return false
				end
			end

			return true
		end

		local sightlines = {}
		local eyes = {entitylib.character.Head.Position, gameCamera.CFrame.Position}
		local function canSee(aim)
			if sightlines[aim] == nil then
				sightlines[aim] = false
				for _, v in eyes do
					if trace(v, aim) then
						sightlines[aim] = true
						break
					end
				end
			end
			return sightlines[aim]
		end

		if getPlacedBlock(blockpos) and (blockpos - origin).Magnitude <= 30 then
			for _, v in sides do
				v = blockpos + v
				if not getPlacedBlock(v) and (solidonly and isOpen(v) or not solidonly and canSee(v)) then
					local direct = {}
					pathcache[key] = {cell = cell, pos = blockpos, cost = 0, path = direct}
					return blockpos, 0, direct
				end
			end
		end

		local visited, queue, distances, exposed, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local node = table.remove(queue, 1)
			if not node then break end
			if visited[node[2]] then continue end
			visited[node[2]] = true

			for _, v in sides do
				v = node[2] + v
				if visited[v] then continue end

				local block = getPlacedBlock(v)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						local cells = exposed[node[2]]
						if cells then
							table.insert(cells, v)
						else
							exposed[node[2]] = {v}
						end
					end
					continue
				end

				local curdist = node[1] + getBlockHits(block, v)
				if curdist < (distances[v] or math.huge) then
					distances[v] = curdist
					path[v] = node[2]
					table.insert(queue, {curdist, v})
				end
			end
		end

		local nearest = breakmethod == breakmethods.Distance
		local previous = store.breakTarget
		local look = gameCamera.CFrame.LookVector
		local candidates = {}
		for i, v in exposed do
			local delta = i - origin
			local magnitude = delta.Magnitude
			if magnitude <= 30 then
				table.insert(candidates, {distances[i], i, v, magnitude, magnitude > 0 and delta:Dot(look) / magnitude or 1, magnitude // 9})
			end
		end

		table.sort(candidates, function(a, b)
			if nearest and a[6] ~= b[6] then
				return a[6] < b[6]
			end
			if a[1] ~= b[1] then
				return a[1] < b[1]
			end
			if previous and (a[2] == previous) ~= (b[2] == previous) then
				return a[2] == previous
			end
			if a[4] ~= b[4] then
				return a[4] < b[4]
			end
			return a[5] > b[5]
		end)

		local pos, cost
		for _, v in candidates do
			for _, v2 in v[3] do
				if solidonly and isOpen(v2) or not solidonly and canSee(v2) then
					pos, cost = v[2], v[1]
					break
				end
			end
			if pos then break end
		end

		pathcache[key] = {cell = cell, pos = pos, cost = cost, path = path}
		return pos, cost, path
	end

	bedwars.placeBlock = function(pos, item)
		if not canPlace() then return end
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar, autotool, wallcheck, method, directonly)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or (vape.Modules.InfiniteFly or {}).Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local localPosition = entitylib.character.RootPart.Position
		local cost, pos, target, path = math.huge
		local direct = false

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3, not wallcheck, method or nil)
			local distance = dpos and (localPosition - dpos).Magnitude or math.huge
			local hit = dpos == v * 3
			if dpos and (hit and not direct or hit == direct and (dcost < cost or (dcost == cost and distance < (localPosition - pos).Magnitude))) then
				cost, pos, target, path, direct = dcost, dpos, v * 3, dpath, hit
			end
		end

		if directonly and not direct then return end

		store.breakTarget = pos

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					if autotool then
						local hotbar = getHotbar(tool.tool)
						if hotbar then
							hotbarSwitch(hotbar)
						end
					else
						switchItem(tool.tool)
					end
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.blockHealthbar:destroy()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation
						if anim ~= 'Minimal' or Random.new(os.clock() * 1.2):NextInteger(0, 1) == 1 then
							animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						end
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(anim == 'Minimal' and 0.01 or 0.3)
						if animation then
							animation:Stop()
							animation:Destroy()
						end
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
		return nil
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType] or {}
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, v in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(v):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[v]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		local damageTable = {
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		}
		markKnockback(damageTable)
		reportProjectileHit(damageTable)
		vapeEvents.EntityDamageEvent:Fire(damageTable)
	end))

	local swordSwing = bedwars.SyncEvents.SwordSwing:setPriority(500):connect(function(event)
		if store.swordSpeeds and event.swordType and typeof(event.attackSpeed) == 'number' then
			store.swordSpeeds[event.swordType] = event.attackSpeed
		end
	end)
	vape:Clean(function()
		swordSwing:Destroy()
	end)

	local projectileLaunched = bedwars.SyncEvents.ProjectileLaunched:connect(function(event)
		if not store.matchState or typeof(event.origin) ~= 'Vector3' or typeof(event.launchVelocity) ~= 'Vector3' or event.shooter == lplr.Character then return end
		scanProjectile(event.origin, event.launchVelocity, event.projectileType, event.shooter)
	end)
	vape:Clean(function()
		projectileLaunched:Destroy()
	end)

	vape:Clean(bedwars.ZapNetworking.BreakBlockEventZap.On(function(...)
		local data = {
			blockRef = {
				blockPosition = ...,
			},
			player = select(5, ...)
		}
		table.clear(pathcache)
		vapeEvents.BreakBlockEvent:Fire(data)
	end))

	store.blocks = collection('block', vape)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, vape, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, vape, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			local map = workspace:WaitForChild('Map', 9e9):WaitForChild('Worlds', 9e9):GetChildren()[1]
			mapname = map.Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
			store.map = map
			vape:Clean(map.Blocks.ChildRemoved:Connect(function()
				table.clear(pathcache)
			end))
			vape:Clean(map.Blocks.ChildAdded:Connect(function(v)
				table.clear(pathcache)
				task.defer(function()
					if v:IsA('BasePart') and v:GetAttribute('Block') and (v:GetAttribute('PlacedByUserId') or 0) ~= 0 then
						local pos = v.Position / 3
						vapeEvents.PlaceBlockEvent:Fire({
							blockRef = {blockPosition = Vector3.new(math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))},
							player = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId'))
						})
					end
				end)
			end))
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat task.wait() until store.map or vape.Loaded == nil
		if vape.Loaded == nil then return end
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = {store.map}
		store.airRay = rayParams

		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or nil
			local gravity, now = workspace.Gravity, tick()
			for _, v in entitylib.List do
				local velocity = v.RootPart.AssemblyLinearVelocity
				v.LandTick = math.abs(velocity.Y) < 0.1 and v.LandTick or now
				if (now - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end

				local moving = velocity.Magnitude > 1
				if (now - (v.TrackTick or 0)) >= (moving and 1 / 30 or 0.2) then
					v.TrackTick = now
					prediction.Observe(v.RootPart, v.RootPart.Position, velocity, v.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(velocity.Y) > 0.01, gravity, moving and localPosition or nil, v.HipHeight, v.Jumping and 42.6 or nil)
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	local KitModules = {
		agni = {'AutoAgni'},
		airbender = {'AutoRamil'},
		alchemist = {'AutoMushroom'},
		beast = {'AutoCrocowolf'},
		beekeeper = {'AutoBeekeeper', 'BeekeeperSpy'},
		berserker = {'AutoRagnar'},
		bigman = {'AutoElder'},
		blood_assassin = {'AutoCaitlyn'},
		bounty_hunter = {'AutoBountyHunter', 'BountyHunterSpy'},
		builder = {'AutoBuilder'},
		cactus = {'AutoMartin'},
		card = {'AutoCard'},
		cat = {'KitExtender'},
		cowgirl = {'AutoLasso'},
		cyber = {'AutoCyber'},
		dasher = {'KitExtender'},
		davey = {'AutoDavey', 'DaveyAim'},
		dragon_slayer = {'AutoKaliyah'},
		dragon_sword = {'AutoDragonSword'},
		drill = {'AutoDrill'},
		elektra = {'AutoElektra'},
		elk_master = {'AutoSigrid'},
		ember = {'AutoEmber'},
		falconer = {'FalconAura'},
		farmer_cletus = {'AutoFarmer'},
		fisherman = {'FishermanSpy'},
		frost_hammer_kit = {'AutoAdetunde'},
		gingerbread_man = {'AutoGingerbreadMan'},
		glacial_skater = {'AutoKrystal', 'InfiniteKrystal'},
		grim_reaper = {'AutoGrim'},
		hannah = {'AutoHannah'},
		harpoon = {'AutoTriton'},
		ice_queen = {'AutoFreiya'},
		jade = {'AutoJade', 'JadeAura', 'KitExtender'},
		jailor = {'AutoWarden'},
		jellyfish = {'AutoMarina'},
		lumen = {'AutoLumen'},
		mage = {'AutoWhim', 'AutoWhimElement'},
		melody = {'AutoMelody'},
		metal_detector = {'AutoMetal', 'MetalDetectorSpy'},
		midnight = {'AutoNyx'},
		mimic = {'AutoPickpocket'},
		nazar = {'AutoNazar'},
		necromancer = {'CryptAura'},
		oasis = {'AutoNahila'},
		owl = {'AutoWhisper', 'OwlAura'},
		paladin = {'AutoLani'},
		pyro = {'AutoPyro'},
		queen_bee = {'AutoFlora'},
		raven = {'RavenTP'},
		rebellion_leader = {'AutoSilas'},
		regent = {'AutoVoidRegent', 'VoidRegentAutoClutch', 'KitExtender'},
		scarab = {'AutoAbaddon'},
		sheep_herder = {'AutoSheepHerder'},
		shielder = {'AutoShielderUlt'},
		skeleton = {'AutoMarrow'},
		slime_tamer = {'AutoNoelle'},
		smoke = {'AutoSmoke'},
		sorcerer = {'DeathAdderAimbot'},
		soul_broker = {'AutoZola'},
		spider_queen = {'AutoArachne'},
		spirit_assassin = {'AutoEvelynn'},
		spirit_gardener = {'AutoGrove'},
		spirit_summoner = {'AutoUma'},
		star_collector = {'AutoStarCollector'},
		steam_engineer = {'AutoCogsworth'},
		summoner = {'AutoKaida'},
		taliyah = {'AutoTaliyah'},
		tinker = {'AutoHephaestus'},
		triple_shot = {'AutoVanessa'},
		vesta = {'AutoConqueror'},
		void_dragon = {'AutoXurot', 'KitExtender'},
		void_hunter = {'AutoSkoll'},
		void_knight = {'AutoVoidKnight'},
		void_walker = {'AutoTrixie'},
		vulcan = {'VulcanAssist'},
		warlock = {'AutoEldric'},
		warrior = {'AutoWarrior'},
		winter_lady = {'AutoSophia'},
		wizard = {'AutoZeno'},
		yeti = {'AutoYeti'}
	}

	local highlighted = {}
	task.spawn(function()
		local lastkit, notified
		repeat
			local kit = store.equippedKit
			if kit ~= lastkit then
				for _, v in highlighted do
					v:SetHighlight(nil)
				end
				table.clear(highlighted)
				lastkit, notified = kit, false
			end

			local names = kit ~= '' and KitModules[kit] or nil
			if names and #highlighted == 0 then
				local shown = {}
				for _, v in names do
					local module = vape.Modules[v]
					if module and module.SetHighlight then
						table.insert(highlighted, module)
						table.insert(shown, module.Name)
						module:SetHighlight(#highlighted)
					end
				end

				if #shown > 0 and not notified then
					notified = true
					local meta = bedwars.BedwarsKitMeta[kit]
					notif('Kits', `This script supports the {(meta and meta.name or kit):lower()} kit!\nModules: {table.concat(shown, ', ')}`, 20, 'info')
				end
			end
			task.wait(1)
		until vape.Loaded == nil
	end)

	task.spawn(function()
		local identity = getthreadidentity and setthreadidentity and getthreadidentity()
		repeat
			if identity then
				setthreadidentity(2)
			end

			local suc, shop = pcall(function()
				return require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			end)

			if identity then
				setthreadidentity(identity)
			end

			if suc and shop then
				bedwars.Shop = shop
				store.shopLoaded = true
				return
			end

			task.wait(2)
		until vape.Loaded == nil
	end)
	vape:Clean(function()
		task.wait(1)
		Client.Get = OldGet
		bedwars.BlockBreaker.hitBlock = OldHit
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(pathcache)
		table.clear(sides)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

local function getFunctionRange(func)
	local last = false
	for _, v in debug.getconstants(func) do
		if v == 'maxActivationDistance' then
			last = true
		elseif last then
			return v and typeof(v) == 'number' and v or nil
		end
	end
	return nil
end
getgenv().getFunctionRange = getFunctionRange

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'Jesus', 'Invisible', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'Wallhop', 'Xray', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end


run(function()
	local AimAssist
	local AimMode
	local Mode
	local Targets
	local Sort
	local AimPart
	local AimSpeed
	local Smoothness
	local Shake
	local Distance
	local AngleSlider
	local StrafeIncrease
	local BlockBreak
	local KillauraTarget
	local ClickAim
	local Mouse
	local Limit
	
	local rng = Random.new()
	local cache = setmetatable({}, {__mode = 'k'})
	
	local function getAim(ent)
		if AimPart.Value == 'Closest' then
			if not cache[ent.Character] then
				cache[ent.Character] = ent.Character:GetChildren()
			end
			local localPosition, magnitude, part = inputService.TouchEnabled and gameCamera.ViewportSize / 2 or inputService:GetMouseLocation(), 9e9, nil
			for _, v in cache[ent.Character] do
				if v and v.Parent and v:IsA('BasePart') then
					local position, vis = gameCamera:WorldToViewportPoint(v.Position)
					if vis then
						local mag = (localPosition - Vector2.new(position.X, position.Y)).Magnitude
						if mag < magnitude then
							magnitude = mag
							part = v
						end
					end
				end
			end
			if part then
				return part.Position
			end
		end
		return ent.RootPart.Position
	end
	
	local started, lasttarget, nextsearch = 0, nil, 0
	local aimfuncs = {
		Simple = function(localcframe, ent, fps)
			local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) / Smoothness.Value
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end,
		Adaptive = function(localcframe, ent, fps)
			local t = math.min(tick() - started, 1)
			local prog = t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
			local speed = ((AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)) / Smoothness.Value
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end
	}
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				local rotate = 0
				AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if entitylib.isAlive then
						entitylib.character.Humanoid.AutoRotate = tick() > rotate
	
						local blocked = Mouse.Enabled and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15
						blocked = blocked or (ClickAim.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3)
						blocked = blocked or (BlockBreak.Enabled and (tick() - store.lastHit) < 0.3)
						blocked = blocked or (Limit.Enabled and store.hand.toolType ~= 'sword')
	
						local ent
						if not blocked then
							if entitylib.isAlive and lasttarget and lasttarget.Character and lasttarget.Character.Parent and lasttarget.RootPart and lasttarget.RootPart.Parent and lasttarget.Targetable and entitylib.isVulnerable(lasttarget) and (entitylib.character.RootPart.Position - lasttarget.RootPart.Position).Magnitude <= Distance.Value and not (Targets.Walls.Enabled and entitylib.Wallcheck(entitylib.character.RootPart.Position, lasttarget.RootPart.Position, Targets.Walls.Enabled, lasttarget)) and tick() < nextsearch then
								ent = lasttarget
							else
								local target = store.KillauraTarget
								ent = KillauraTarget.Enabled and entitylib.isAlive and target and target.Character and target.Character.Parent and target.RootPart and target.RootPart.Parent and target.Targetable and entitylib.isVulnerable(target) and (entitylib.character.RootPart.Position - target.RootPart.Position).Magnitude <= Distance.Value and not (Targets.Walls.Enabled and entitylib.Wallcheck(entitylib.character.RootPart.Position, target.RootPart.Position, Targets.Walls.Enabled, target)) and target or entitylib.EntityPosition({
									Range = Distance.Value,
									Part = 'RootPart',
									Wallcheck = Targets.Walls.Enabled,
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Priority = Targets.Priority.Value,
									Sort = sortmethods[Sort.Value]
								})
								if ent ~= lasttarget then
									started = tick()
								end
								lasttarget = ent
								nextsearch = tick() + 1
							end
						end
	
						if ent then
							local root = entitylib.character.RootPart
							local delta = (ent.RootPart.Position - root.Position)
							local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
							local horizontal = delta * Vector3.new(1, 0, 1)
							local angle = localfacing.Magnitude > 0 and horizontal.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(horizontal.Unit), -1, 1)) or 0
							if angle >= (math.rad(AngleSlider.Value) / 2) then
								return
							end
							targetinfo.Targets[ent] = tick() + 1
	
							local firstPerson = entitylib.character.Head.LocalTransparencyModifier == 1
							local perspective = AimMode.Value
							if perspective == 'Mouse' then
								local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
								local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
								mousemoverel(pos.X, pos.Y)
							elseif perspective == 'First person' or (perspective == 'Dynamic' and firstPerson) then
								if not firstPerson then return end
								local cframe = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								gameCamera.CFrame = cframe
							elseif perspective == 'Third person' or (perspective == 'Dynamic' and not firstPerson) then
								if firstPerson then return end
								local cframe = aimfuncs[Mode.Value](root.CFrame, ent, dt)
								local direction = cframe.LookVector * Vector3.new(1, 0, 1)
								if direction.Magnitude > 0 then
									entitylib.character.Humanoid.AutoRotate = false
									root.CFrame = CFrame.lookAlong(root.Position, direction)
									rotate = tick() + 0.1
								end
							end
						end
					else
						lasttarget = nil
					end
				end))
			else
				lasttarget = nil
				if entitylib.isAlive then
					entitylib.character.Humanoid.AutoRotate = true
				end
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})
	
	AimMode = AimAssist:CreateDropdown({
		Name = 'Aim perspective',
		Tooltip = 'First person - Uses your camera to aim\nThird person - Moves your character to where your supposed to look\nMouse - Moves your mouse & camera\nDynamic - Uses first person mode if ur in first person, and uses third person if ur in third person',
		List = {'First person', 'Third person', 'Dynamic'},
		Default = 'First person'
	})
	Mode = AimAssist:CreateDropdown({
		Name = 'Mode',
		List = {'Simple', 'Adaptive'},
		Tooltip = 'Simple - Smooth aiming\nAdaptive - Advanced tracking with adaptive behavior',
		Default = 'Simple'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Angle', 'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click aim',
		Default = true
	})
	Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
	BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
	KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Smoothness = AimAssist:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 20,
		Default = 1,
		Decimal = 10,
		Tooltip = 'Divides the aim speed to soften the snap, 1 leaves aiming unchanged'
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Shake = AimAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter to simulate human aim'
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	Limit = AimAssist:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks when sword is held'
	})
	Sort = AimAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Angle'
	})
	AimPart = AimAssist:CreateDropdown({
		Name = 'Target area',
		List = {'Center', 'Closest'},
		Default = 'Center'
	})
end)

run(function()
	local AutoClicker
	local CPS
	local Place
	local Wool
	local BlockCPS = {}
	local Thread
	
	local function AutoClick()
		if Thread then
			task.cancel(Thread)
		end
	
		Thread = task.delay(store.hand.toolType == 'block' and math.max(1 / BlockCPS:GetRandomValue(), 1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12)) or 1 / CPS:GetRandomValue(), function()
			repeat
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					local blockPlacer = bedwars.BlockPlacementController.blockPlacer
					if store.hand.toolType == 'block' and Place.Enabled and (Wool.Enabled and store.hand.tool.Name:find('wool_') or not Wool.Enabled) and blockPlacer and canPlace() then
						if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12)) * 0.5) then
							if inputService.TouchEnabled then
								task.spawn(blockPlacer.autoBridge, blockPlacer, workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
							else
								local selector = blockPlacer.clientManager:getBlockSelector()
								local mouseinfo = selector and selector:getMouseInfo(0)
								if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition, mouseinfo)
								end
							end
						end
					elseif store.hand.toolType == 'sword' then
						if inputService.TouchEnabled then
							bedwars.SwordController:mobileSwingPressed()
						elseif canSwing() and not bedwars.SwordController.disableSwingState then
							bedwars.SwordController:swingSwordAtMouse(0.39)
						end
					end
				end
	
				task.wait(store.hand.toolType == 'block' and math.max(1 / BlockCPS:GetRandomValue(), 1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12)) or 1 / CPS:GetRandomValue())
			until not AutoClicker.Enabled
		end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
					local keybinds = bedwars.KeybindLoadController:getKeybinds()
					local keyboard = keybinds and keybinds.keyboard and keybinds.keyboard.controlActions.Attack or Enum.UserInputType.MouseButton1
					local gamepad = keybinds and keybinds.gamepad and keybinds.gamepad.controlActions.Attack or Enum.KeyCode.ButtonR2
					if input.UserInputType == keyboard or input.KeyCode == keyboard or input.KeyCode == gamepad then
						AutoClick()
					end
				end))
	
				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					local keybinds = bedwars.KeybindLoadController:getKeybinds()
					local keyboard = keybinds and keybinds.keyboard and keybinds.keyboard.controlActions.Attack or Enum.UserInputType.MouseButton1
					local gamepad = keybinds and keybinds.gamepad and keybinds.gamepad.controlActions.Attack or Enum.KeyCode.ButtonR2
					if (input.UserInputType == keyboard or input.KeyCode == keyboard or input.KeyCode == gamepad) and Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end))
	
				if inputService.TouchEnabled then
					local hooked = {}
					local function hookButton(button)
						if hooked[button] or not button:IsA('GuiButton') or not tonumber(button.Name) then return end
						hooked[button] = true
						AutoClicker:Clean(button.MouseButton1Down:Connect(AutoClick))
						AutoClicker:Clean(button.MouseButton1Up:Connect(function()
							if Thread then
								task.cancel(Thread)
								Thread = nil
							end
						end))
					end
	
					task.spawn(function()
						local mobileUI = lplr.PlayerGui:WaitForChild('MobileUI', 20)
						if not mobileUI or not AutoClicker.Enabled then return end
	
						for _, v in mobileUI:GetChildren() do
							hookButton(v)
						end
						AutoClicker:Clean(mobileUI.ChildAdded:Connect(hookButton))
					end)
				end
			else
				if Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	Place = AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
	
			if Wool then
				Wool.Object.Visible = callback
			end
		end,
		Default = true
	})
	Wool = AutoClicker:CreateToggle({Name = 'Wool only', Tooltip = 'Only clicks when you are holding wool.', Darker = true})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 12,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true
	})
end)

run(function()
	local BowAssist
	local Targets
	local Sort
	local AimPart
	local FOV
	local AimSpeed
	local Smoothness
	local Distance
	local Shake
	local Clear
	local Blacklist
	
	local drawStart, oldStart, oldStop = 0
	local rng = Random.new()
	
	local arcCheck = RaycastParams.new()
	arcCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	BowAssist = vape.Categories.Combat:CreateModule({
		Name = 'BowAssist',
		Function = function(callback)
			if callback then
				oldStart = bedwars.DefaultProjectileSourceController.onStartCharging
				bedwars.DefaultProjectileSourceController.onStartCharging = function(self, ...)
					drawStart = tick()
					return oldStart(self, ...)
				end
	
				oldStop = bedwars.DefaultProjectileSourceController.onStopCharging
				bedwars.DefaultProjectileSourceController.onStopCharging = function(self, ...)
					drawStart = 0
					return oldStop(self, ...)
				end
	
				BowAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if drawStart == 0 or not entitylib.isAlive then return end
	
					local meta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
					local source = meta and meta.projectileSource
					if not source or not source.projectileType then return end
	
					local ammo = store.hand.tool.Name
					if source.ammoItemTypes and #source.ammoItemTypes > 0 then
						ammo = nil
						for _, v in store.inventory.inventory.items do
							if table.find(source.ammoItemTypes, v.itemType) then
								ammo = v.itemType
								break
							end
						end
					end
					if not ammo then return end
	
					local projType = source.projectileType(ammo)
					if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then return end
	
					local projmeta = bedwars.ProjectileMeta[projType]
					if not projmeta or type(projmeta.launchVelocity) ~= 'number' then return end
	
					local scalar = source.minStrengthScalar or 1
					local ratio = source.maxStrengthChargeSec and math.clamp((tick() - drawStart) / source.maxStrengthChargeSec, 0, 1) or 1
					local projSpeed = projmeta.launchVelocity * (scalar + (1 - scalar) * ratio)
	
					local localPosition = entitylib.character.RootPart.Position
					local ent = entitylib.EntityMouse({
						Range = FOV.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Origin = localPosition,
						Sort = sortmethods[Sort.Value]
					})
					if not ent or (localPosition - ent.RootPart.Position).Magnitude > Distance.Value then return end
	
					local targetPosition = ent[AimPart.Value].Position
					local shootPosition = (CFrame.new(localPosition, targetPosition) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
					local gravity = projmeta.gravitationalAcceleration or 196.2
					local calc, _, travelTime = prediction.SolveTrajectory(shootPosition, projSpeed, gravity, targetPosition, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true)
					if not calc then return end
	
					if Clear.Enabled and travelTime then
						local ignorelist = {gameCamera, lplr.Character}
						for _, v in entitylib.List do
							if v.Character then
								table.insert(ignorelist, v.Character)
							end
						end
						arcCheck.FilterDescendantsInstances = ignorelist
						if not prediction.IsTrajectoryClear(shootPosition, calc - shootPosition, gravity, travelTime, arcCheck) then return end
					end
	
					targetinfo.Targets[ent] = tick() + 1
					local jitter = Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * dt, (rng:NextNumber() - 0.5) * Shake.Value * dt, (rng:NextNumber() - 0.5) * Shake.Value * dt)
					gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position, calc + jitter), math.clamp((AimSpeed.Value / Smoothness.Value) * dt, 0, 1))
				end))
			else
				drawStart = 0
				bedwars.DefaultProjectileSourceController.onStartCharging = oldStart
				bedwars.DefaultProjectileSourceController.onStopCharging = oldStop
			end
		end,
		Tooltip = 'Eases your camera onto the arrow drop while you draw a bow'
	})
	
	Targets = BowAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = BowAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance'
	})
	AimPart = BowAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = BowAssist:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 220,
		Tooltip = 'How far from your crosshair a target can sit before it gets ignored'
	})
	Distance = BowAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 300,
		Default = 200,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AimSpeed = BowAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 5
	})
	Smoothness = BowAssist:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 20,
		Default = 2,
		Decimal = 10,
		Tooltip = 'Divides the aim speed to soften the pull, 1 leaves it unchanged'
	})
	Shake = BowAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter so the pull does not read as a straight line'
	})
	Clear = BowAssist:CreateToggle({
		Name = 'Clear shot only',
		Default = true,
		Tooltip = 'Stops assisting when a block is in the way of the arc'
	})
	Blacklist = BowAssist:CreateTextList({
		Name = 'Blacklist',
		Default = {'gloop', 'telepearl'},
		Darker = true,
		Placeholder = 'projectile',
		Tooltip = 'Projectile types the assist leaves alone'
	})
end)

run(function()
	local ChargeAura
	local Targets
	local Mode
	local TargetPart
	local Hitreg
	local Range
	local Charge
	local Swap
	local Animation
	
	local AttackRemote = {Fire = function() end}
	local nextAttack = 0
	local nextSwap = 0
	
	local function getCharged(tool)
		local itemmeta = tool and bedwars.ItemMeta[tool.Name]
		local swordmeta = itemmeta and itemmeta.sword
		return swordmeta and swordmeta.chargedAttack or nil
	end
	
	local function getChargedWeapon()
		local best, bestdamage = nil, -1
		for _, v in store.inventory.inventory.items do
			local itemmeta = bedwars.ItemMeta[v.itemType]
			local swordmeta = itemmeta and itemmeta.sword
			if swordmeta and swordmeta.chargedAttack then
				local damage = (swordmeta.damage or 0) + (swordmeta.chargedAttack.bonusDamage or 0)
				if damage > bestdamage then
					best, bestdamage = v, damage
				end
			end
		end
		return best
	end
	
	local function getChargeTime(charged)
		local min = charged.minChargeTimeSec or 0
		local max = math.max(charged.maxChargeTimeSec or min, min)
		return min + ((max - min) * (Charge.Value / 100))
	end
	
	local function getCooldown(tool, charged)
		return charged.attackCooldown or getSwordSpeed(tool)
	end
	
	local function releaseCharge(tool, charged)
		local started = bedwars.SwordChargeController:getChargeStartTime()
		local chargeTime = started > 0 and (tick() - started) or getChargeTime(charged)
		bedwars.SwordChargeController:stopCharging(tool.Name)
	
		if not (charged.skipSwingDamage and chargeTime > (charged.minChargeTimeSec or 0)) then
			bedwars.SwordController:swingSwordAtMouse(chargeTime)
		end
	
		bedwars.SyncEvents.SwordChargedSwing:fire(lplr, tool, {chargeTime = chargeTime})
		return chargeTime
	end
	
	local function attack(entity, tool, charged, chargeTime)
		local selfpos = entitylib.character.RootPart.Position
		local targetpos = getTargetPart(entity, TargetPart.Value).Position
		local delta = targetpos - selfpos
		local dir = delta.Magnitude > 0.001 and delta.Unit or Vector3.new(0, -1, 0)
		local reach = getReach(tool) or 0
		local pos = selfpos + dir * math.max(delta.Magnitude - (reach - 0.001), 0)
		local ratio = 1
	
		if charged.maxChargeTimeSec and charged.maxChargeTimeSec > 0 then
			ratio = math.clamp(chargeTime / charged.maxChargeTimeSec, 0, 1)
		end
	
		bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
		store.attackReach = (delta.Magnitude * 100) // 1 / 100
		store.attackReachUpdate = tick() + 1
	
		AttackRemote:Fire(nil, {
			weapon = tool,
			chargedAttack = {chargeRatio = ratio},
			entityInstance = entity.Character,
			validate = {
				raycast = {
					cameraPosition = {value = pos},
					cursorDirection = {value = dir}
				},
				targetPosition = {value = targetpos},
				selfPosition = {value = pos}
			}
		})
	end
	
	ChargeAura = vape.Categories.Combat:CreateModule({
		Name = 'ChargeAura',
		Function = function(callback)
			if callback then
				AttackRemote = bedwars.Handler:Get('SwordHit')
				nextAttack = 0
				nextSwap = 0
	
				repeat
					if entitylib.isAlive and not isCasting() and not bedwars.SwordController:getSwordSwingDisabled() then
						local tool = store.hand.tool
						local charged = getCharged(tool)
						local weapon = (not charged and Swap.Enabled) and getChargedWeapon() or nil
						local reachTool = charged and tool or (weapon and weapon.tool)
	
						if reachTool then
							local target = entitylib.EntityPosition({
								Range = Range.Value + (getReach(reachTool) or 0),
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Priority = Targets.Priority.Value,
								Wallcheck = Targets.Walls.Enabled,
								Sort = sortmethods[Mode.Value]
							})
	
							if target and weapon and tick() >= nextSwap then
								local hotbar = getHotbar(weapon.tool)
								if hotbar then
									hotbarSwitch(hotbar)
								end
								switchItem(weapon.tool)
								nextSwap = tick() + 0.3
								tool = store.hand.tool
								charged = getCharged(tool)
							end
	
							if charged and target then
								store.attacking = true
	
								if tick() >= nextAttack then
									local chargeTime = getChargeTime(charged)
	
									if Hitreg.Value == 'Charge' then
										if bedwars.SwordChargeController:getChargeState() == bedwars.ChargeState.Idle then
											bedwars.SwordChargeController:startCharging(tool.Name)
										end
	
										local started = bedwars.SwordChargeController:getChargeStartTime()
										if started > 0 and (tick() - started) >= chargeTime then
											chargeTime = releaseCharge(tool, charged)
											attack(target, tool, charged, chargeTime)
											nextAttack = tick() + getCooldown(tool, charged)
										end
									else
										if Animation.Enabled then
											bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										end
										attack(target, tool, charged, chargeTime)
										nextAttack = tick() + getCooldown(tool, charged)
									end
								end
							elseif charged then
								store.attacking = false
								if bedwars.SwordChargeController:getChargeState() ~= bedwars.ChargeState.Idle then
									bedwars.SwordChargeController:stopCharging(tool.Name)
								end
							end
						end
					end
					task.wait()
				until not ChargeAura.Enabled
	
				store.attacking = false
				local tool = store.hand.tool
				if tool and bedwars.SwordChargeController:getChargeState() ~= bedwars.ChargeState.Idle then
					bedwars.SwordChargeController:stopCharging(tool.Name)
				end
			end
		end,
		Tooltip = 'Aura for charged weapons like great hammers and scythes, which the normal aura ignores entirely'
	})
	
	Targets = ChargeAura:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	local methods = {'Distance', 'Health'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Mode = ChargeAura:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance'
	})
	TargetPart = ChargeAura:CreateDropdown({
		Name = 'Target part',
		List = partlist,
		Default = 'RootPart'
	})
	Hitreg = ChargeAura:CreateDropdown({
		Name = 'Hitreg',
		List = {'Instant', 'Charge'},
		Default = 'Instant',
		Function = function(val)
			if Charge then
				Charge.Object.Visible = val == 'Charge'
			end
		end,
		Tooltip = 'Instant - swings on the weapon cooldown for base damage\nCharge - winds the weapon up first, half as many swings but double the damage each, and its slam or wave still goes off'
	})
	Range = ChargeAura:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 20,
		Default = 3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Added on top of the weapons own attack range'
	})
	Charge = ChargeAura:CreateSlider({
		Name = 'Charge',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Visible = false,
		Tooltip = 'How far between the weapons minimum and maximum charge to wind up before releasing'
	})
	Swap = ChargeAura:CreateToggle({
		Name = 'Auto swap',
		Default = true,
		Tooltip = 'Holds your strongest charged weapon once something walks into range'
	})
	Animation = ChargeAura:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays a swing on every instant hit'
	})
	
end)

run(function()
	ChargeSpoof = vape.Categories.Combat:CreateModule({
		Name = 'ChargeSpoof',
		Tooltip = 'Reports every swing as charged so hammers, scythes and sabers deal their charged bonus without holding the charge'
	})
	
	ChargeRatio = ChargeSpoof:CreateSlider({
		Name = 'Charge',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Tooltip = 'Charge the server is told you held, 100% is the full bonus damage'
	})
end)

run(function()
	local NoClickDelay
	local SwingLock
	local Drill
	local old, olddrill, oldlock
	
	NoClickDelay = vape.Categories.Combat:CreateModule({
		Name = 'NoClickDelay',
		Function = function(callback)
			if callback then
				old = bedwars.SwordController.isClickingTooFast
				bedwars.SwordController.isClickingTooFast = function(self)
					self.lastSwing = tick()
					return false
				end
	
				if SwingLock.Enabled then
					oldlock = bedwars.SwordController.getSwordSwingDisabled
					bedwars.SwordController.getSwordSwingDisabled = function()
						return false
					end
				end
	
				if Drill.Enabled then
					olddrill = bedwars.DrillTabletController.isClickingTooFast
					bedwars.DrillTabletController.isClickingTooFast = function()
						return false
					end
				end
			else
				bedwars.SwordController.isClickingTooFast = old
	
				if oldlock then
					bedwars.SwordController.getSwordSwingDisabled = oldlock
					oldlock = nil
				end
	
				if olddrill then
					bedwars.DrillTabletController.isClickingTooFast = olddrill
					olddrill = nil
				end
			end
		end,
		Tooltip = 'Removes the 9 clicks a second cap the client puts on swinging'
	})
	
	SwingLock = NoClickDelay:CreateToggle({
		Name = 'Swing lock',
		Function = function()
			if NoClickDelay.Enabled then
				NoClickDelay:Toggle()
				NoClickDelay:Toggle()
			end
		end,
		Tooltip = 'Also lets you swing while a kit ability has swinging turned off, like sigrid on her elk'
	})
	Drill = NoClickDelay:CreateToggle({
		Name = 'Drill',
		Function = function()
			if NoClickDelay.Enabled then
				NoClickDelay:Toggle()
				NoClickDelay:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Removes the same cap on the drill tablet'
	})
end)

run(function()
	local BlockReach
	local BlockRange
	local BreakReach
	local BreakRange
	local SwordReach
	local SwordRange
	
	local old
	local swingConnection
	local lastExtendedSwing = 0
	
	local function extendedSwordHit()
		if not entitylib.isAlive then return end
	
		local sword = getSword()
		if not sword or (tick() - lastExtendedSwing) < getSwordSpeed(sword.tool) then return end
	
		local reach = getReach(sword.tool)
		local localPosition = entitylib.character.RootPart.Position
		local target = entitylib.EntityPosition({
			Origin = localPosition,
			Range = SwordRange.Value + 2,
			Part = 'RootPart',
			Players = true,
			NPCs = true,
			Wallcheck = true
		})
		if not target then return end
	
		local delta = target.RootPart.Position - localPosition
		if delta.Magnitude <= reach then return end
	
		local direction = CFrame.lookAt(localPosition, target.RootPart.Position).LookVector
		lastExtendedSwing = tick()
		bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
		bedwars.Handler:Get('SwordHit'):Fire('SendToServer', {
			weapon = sword.tool,
			chargedAttack = {chargeRatio = 0},
			entityInstance = target.Character,
			validate = {
				raycast = {
					cameraPosition = {value = gameCamera.CFrame.Position},
					cursorDirection = {value = direction}
				},
				targetPosition = {value = target.Character:GetPivot().Position},
				selfPosition = {value = localPosition + direction * math.max(delta.Magnitude - (reach - 0.001), 0)}
			}
		})
	end
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
			if callback then
				old = bedwars.BlockSelector.getMouseInfo
				bedwars.BlockSelector.getMouseInfo = function(self, mode, args)
					args = args or {}
					if mode == 0 then
						args.range = BlockReach.Enabled and BlockRange.Value or 24
					elseif mode == 1 then
						args.range = BreakReach.Enabled and BreakRange.Value or 18
					end
					return old(self, mode, args)
				end
			else
				bedwars.BlockSelector.getMouseInfo = old
			end
	
			if swingConnection then
				swingConnection:Disconnect()
				swingConnection = nil
			end
			if not canDebug and Reach.Enabled and SwordReach.Enabled then
				swingConnection = inputService.InputBegan:Connect(function(input, processed)
					if processed then return end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	
					extendedSwordHit()
				end)
			end
		end,
		Tooltip = 'Allows you to place, attack, and break further'
	})
	
	SwordReach = Reach:CreateToggle({
		Name = 'Sword Reach',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
			if SwordRange then
				SwordRange.Object.Visible = callback
			end
	
			if swingConnection then
				swingConnection:Disconnect()
				swingConnection = nil
			end
			if not canDebug and Reach.Enabled and callback then
				swingConnection = inputService.InputBegan:Connect(function(input, processed)
					if processed then return end
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	
					extendedSwordHit()
				end)
			end
		end,
		Default = true
	})
	SwordRange = Reach:CreateSlider({
		Name = 'Sword Range',
		Min = 1,
		Max = 18,
		Decimal = 5,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Function = function(val)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4
		end,
		Default = 18
	})
	BlockReach = Reach:CreateToggle({
		Name = 'Placement Reach',
		Function = function(callback)
			BlockRange.Object.Visible = callback
		end
	})
	BlockRange = Reach:CreateSlider({
		Name = 'Placement Range',
		Min = 1,
		Max = 60,
		Default = 18,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Visible = false
	})
	BreakReach = Reach:CreateToggle({
		Name = 'Break Reach',
		Function = function(callback)
			BreakRange.Object.Visible = callback
		end
	})
	BreakRange = Reach:CreateSlider({
		Name = 'Break Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 5,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Visible = false
	})
	Reach:CreateButton({
		Name = 'Reset to default reach',
		Function = function()
			BreakRange:SetValue(18)
			BlockRange:SetValue(24)
			SwordRange:SetValue(12.4)
		end,
		Tooltip = 'Resets every range back to default'
	})
end)

run(function()
	local SilentAim
	local Targets
	local TargetPart
	local Sort
	local Prediction
	local FOV
	local OtherProjectiles
	local Blacklist
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	
	local namecall
	local lastWarn = 0
	
	local function solveSilent(args)
		local origin, velocity, projType = args[4], args[6], args[3]
		if typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' or type(projType) ~= 'string' then
			return
		end
	
		if (not OtherProjectiles.Enabled) and not projType:find('arrow') then
			return
		end
	
		if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then
			return
		end
	
		local meta = bedwars.ProjectileMeta[projType]
		if not meta then return end
	
		local speed = velocity.Magnitude
		if speed <= 0 then return end
	
		local map = workspace:FindFirstChild('Map')
		if map ~= rayCheck.FilterDescendantsInstances[1] then
			rayCheck.FilterDescendantsInstances = map and {map} or {}
		end
		local gravity = meta.gravitationalAcceleration or 196.2
	
		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[Sort.Value or 'Distance'],
			MouseOrigin = gameCamera.ViewportSize / 2,
			Origin = origin
		})
		if not plr then return end
	
		local targetpart = getTargetPart(plr, TargetPart.Value)
		local targetpos
		if TargetPart.Value == 'Closest' then
			local center, magnitude = gameCamera.ViewportSize / 2, 9e9
			for _, v in plr.Character:GetChildren() do
				if v:IsA('BasePart') then
					local position, vis = gameCamera:WorldToViewportPoint(v.Position)
					if vis then
						local mag = (center - Vector2.new(position.X, position.Y)).Magnitude
						if mag < magnitude then
							magnitude, targetpos = mag, v.Position
						end
					end
				end
			end
			targetpos = targetpos or plr.Character.PrimaryPart and plr.Character.PrimaryPart.Position
		elseif TargetPart.Value == 'Dynamic' then
			local tool = store.hand.tool
			if tool and tool.Name:find('headhunter') and plr.Character:FindFirstChild('Head') then
				targetpos = plr.Character.Head.Position
			else
				targetpos = plr.Character.PrimaryPart and plr.Character.PrimaryPart.Position
			end
		end
	
		targetpos = targetpos or targetpart and targetpart.Position
		if not targetpos then return end
		local playerGravity = workspace.Gravity
		local balloons = plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
	
		if plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
	
		if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
			for _, v in collectionService:GetTagged('Owl') do
				if v:GetAttribute('Target') == plr.Player.UserId and v:GetAttribute('Status') == 2 then
					playerGravity = 0
				end
			end
		end
	
		local pearl = projType == 'telepearl'
		local targetVelocity = pearl and Vector3.zero or plr.RootPart.AssemblyLinearVelocity
		local targetAirborne = not pearl and plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
		local calc, _, travelTime = prediction.SolveTrajectory(origin, speed * Prediction.Value, gravity, targetpos, targetVelocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck, targetAirborne, plr.RootPart.Position, plr.RootPart, nil, true)
		if not calc or not travelTime or travelTime > (meta.lifetimeSec or 3) then return end
	
		targetinfo.Targets[plr] = tick() + 1
		store.hitchance.SilentAim = {Value = getHitChance(plr, travelTime), Clock = tick()}
		return CFrame.lookAt(origin, calc).LookVector * speed
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Function = function(callback)
			if callback and not namecall then
				namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
					if SilentAim.Enabled and not checkcaller() and getnamecallmethod() == 'InvokeServer' and tostring(...) == 'ProjectileFire' then
						local self = ...
						local args = table.pack(select(2, ...))
						local success, newVelocity = pcall(solveSilent, args)
						if success and typeof(newVelocity) == 'Vector3' then
							args[6] = newVelocity
						elseif not success and shared.VapeDeveloper and tick() > lastWarn then
							lastWarn = tick() + 5
							warn('[KingVape] silentaim solve failed: '..tostring(newVelocity))
						end
						return namecall(self, table.unpack(args, 1, args.n))
					end
					return namecall(...)
				end))
			end
		end,
		Tooltip = 'Redirects only the projectile values sent to the server, so enemies get hit while your shot flies exactly where you aimed on your own screen'
	})
	
	Targets = SilentAim:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic', 'Closest'}
	})
	local methods = {'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = SilentAim:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Function = function(callback)
			if Blacklist then
				Blacklist.Object.Visible = callback
			end
		end,
		Default = true
	})
	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Default = {'gloop', 'telepearl'},
		Darker = true,
		Placeholder = 'projectile'
	})
end)

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function()
					task.delay(0.1, function()
						bedwars.SprintController:stopSprinting()
					end)
				end))
				bedwars.SprintController:stopSprinting()
			else
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)

run(function()
	local TriggerBot
	local Targets
	local Range
	local Angle
	local CPS
	local Limit
	local Region
	local Continue
	local Duration
	local Mouse
	local AFKCheck
	local GUI
	local BoxColor
	local BoxTween
	local BoxSpeed
	
	local box
	local lastTarget, lastSwing, killUntil = nil, 0, 0
	local rayParams = RaycastParams.new()
	
	local function getTarget(localPosition, attackRange, angle)
		if angle > 0 then
			local ent = entitylib.EntityMouse({
				Part = 'RootPart',
				Range = angle,
				MouseOrigin = gameCamera.ViewportSize / 2,
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled,
				Priority = Targets.Priority.Value,
				Wallcheck = Targets.Walls.Enabled,
				Origin = localPosition
			})
			if not ent or (localPosition - ent.RootPart.Position).Magnitude > attackRange then return nil end
	
			return ent
		end
	
		local unit = lplr:GetMouse().UnitRay
		rayParams.FilterDescendantsInstances = {lplr.Character}
		local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
		if not ray then return nil end
	
		for _, v in entitylib.List do
			if v.Targetable and ray.Instance:IsDescendantOf(v.Character) and (localPosition - v.RootPart.Position).Magnitude <= attackRange then
				if Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and not v.Player then
					if not Targets.Walls.Enabled or not entitylib.Wallcheck(localPosition, v.RootPart.Position, true, v) then
						return v
					end
				end
			end
		end
	
		return nil
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				lastTarget, lastSwing, killUntil = nil, 0, 0
	
				repeat
					local ent, doAttack
					if entitylib.isAlive and (not GUI.Enabled or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)) and (not Mouse.Enabled or inputService:IsMouseButtonPressed(0)) and (not AFKCheck.Enabled or not isAfk()) then
						if (not Limit.Enabled or store.hand.toolType == 'sword') and bedwars.DaoController.chargingMaid == nil then
							local attackRange = math.clamp(Range.Value, 0, getReach(store.hand.tool) * 2)
							ent = getTarget(entitylib.character.RootPart.Position, attackRange, Angle.Value)
							doAttack = ent ~= nil
	
							if lastTarget and lastTarget.Health <= 0 then
								if tick() - lastSwing <= 1 then
									killUntil = tick() + Duration.Value
								end
								lastTarget = nil
							end
	
							if not doAttack and Region.Enabled then
								doAttack = bedwars.SwordController:getTargetInRegion(attackRange, 0) ~= nil
							end
	
							if not doAttack and Continue.Enabled and tick() < killUntil then
								doAttack = true
							end
	
							if ent then
								lastTarget = ent
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if doAttack and canSwing() then
								if ent then
									lastSwing = tick()
								end
								bedwars.SwordController:swingSwordAtMouse()
							end
						end
					end
	
					if box then
						box.Adornee = ent and ent.RootPart or nil
						tweenService:Create(box, TweenInfo.new(BoxSpeed.Value, Enum.EasingStyle[BoxTween.Value]), {
							Size = ent and Vector3.new(4, 6, 4) or Vector3.zero
						}):Play()
						if ent then
							box.Color3 = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
							box.Transparency = 1 - BoxColor.Opacity
						end
					end
	
					task.wait(doAttack and 1 / CPS:GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = TriggerBot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 18,
		Default = 18,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Clamped by the reach of whatever you are holding'
	})
	Angle = TriggerBot:CreateSlider({
		Name = 'Angle',
		Min = 0,
		Max = 1000,
		Default = 0,
		Tooltip = 'Swings at entities near the middle of your screen instead of only the one under your cursor'
	})
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	Limit = TriggerBot:CreateToggle({
		Name = 'Limit to items',
		Default = true,
		Tooltip = 'Only swings when the sword is held'
	})
	Region = TriggerBot:CreateToggle({
		Name = 'Region check',
		Default = true,
		Tooltip = 'Also swings when the game reports anything inside your sword region'
	})
	Continue = TriggerBot:CreateToggle({
		Name = 'Continue after kill',
		Function = function(callback)
			Duration.Object.Visible = callback
		end,
		Tooltip = 'Keeps swinging for a moment after the entity you were on dies, so a second one walking in gets hit right away'
	})
	Duration = TriggerBot:CreateSlider({
		Name = 'Continue time',
		Min = 0.05,
		Max = 2,
		Default = 0.4,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = 'seconds'
	})
	Mouse = TriggerBot:CreateToggle({Name = 'Require mouse down'})
	AFKCheck = TriggerBot:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops attacking once you have not touched your mouse or keyboard for 30 seconds'
	})
	GUI = TriggerBot:CreateToggle({Name = 'GUI check'})
	TriggerBot:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxColor.Object.Visible = callback
			BoxTween.Object.Visible = callback
			BoxSpeed.Object.Visible = callback
			if callback then
				box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.zero
				box.CFrame = CFrame.new(0, -0.5, 0)
				box.ZIndex = 0
				box.Parent = vape.gui
			elseif box then
				box:Destroy()
				box = nil
			end
		end
	})
	local animlist = {'Bounce'}
	for _, v in Enum.EasingStyle:GetEnumItems() do
		if not table.find(animlist, v.Name) then
			table.insert(animlist, v.Name)
		end
	end
	BoxTween = TriggerBot:CreateDropdown({
		Name = 'Box Animation',
		List = animlist,
		Darker = true,
		Visible = false
	})
	BoxSpeed = TriggerBot:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 10,
		Default = 0.9,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	BoxColor = TriggerBot:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
end)

run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()
	local knockbackModule = replicatedStorage.TS.damage['knockback-util']
	local defaults
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if not canDebug then
				if callback then
					defaults = defaults or {
						horizontal = knockbackModule:GetAttribute('ConstantManager_kbDirectionStrength'),
						vertical = knockbackModule:GetAttribute('ConstantManager_kbUpwardStrength')
					}
					knockbackModule:SetAttribute('ConstantManager_kbDirectionStrength', defaults.horizontal * (Horizontal.Value / 100))
					knockbackModule:SetAttribute('ConstantManager_kbUpwardStrength', defaults.vertical * (Vertical.Value / 100))
				elseif defaults then
					knockbackModule:SetAttribute('ConstantManager_kbDirectionStrength', defaults.horizontal)
					knockbackModule:SetAttribute('ConstantManager_kbUpwardStrength', defaults.vertical)
				end
				return
			end
	
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})
	
					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end
	
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Suffix = '%',
		Function = function()
			if not canDebug and Velocity.Enabled and defaults then
				knockbackModule:SetAttribute('ConstantManager_kbDirectionStrength', defaults.horizontal * (Horizontal.Value / 100))
				knockbackModule:SetAttribute('ConstantManager_kbUpwardStrength', defaults.vertical * (Vertical.Value / 100))
			end
		end,
		Default = 0
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Suffix = '%',
		Function = function()
			if not canDebug and Velocity.Enabled and defaults then
				knockbackModule:SetAttribute('ConstantManager_kbDirectionStrength', defaults.horizontal * (Horizontal.Value / 100))
				knockbackModule:SetAttribute('ConstantManager_kbUpwardStrength', defaults.vertical * (Vertical.Value / 100))
			end
		end,
		Default = 0
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)

run(function()
	local AntiDeath
	local StopThreshold
	local Threshold
	local Notify
	local Delay
	local Mode
	
	local oldroot, oldchar, clone, hip
	local paused, activated = 0, 0
	
	local function destroyClone()
		if not oldroot then return false end
	
		local restored = false
		if oldroot.Parent and oldchar and oldchar.Parent then
			oldchar.Parent = replicatedStorage
			oldroot.Parent = oldchar
			if clone then
				clone:Destroy()
			end
			oldchar.PrimaryPart = oldroot
			oldchar.Parent = workspace
			oldroot.CanCollide = true
			local humanoid = oldchar:FindFirstChildOfClass('Humanoid')
			if humanoid then
				humanoid.HipHeight = hip
			end
			restored = true
		elseif clone then
			clone:Destroy()
		end
	
		oldroot, oldchar, clone = nil, nil, nil
		store.rootpart = nil
		return restored
	end
	
	AntiDeath = vape.Categories.Blatant:CreateModule({
		Name = 'AntiDeath',
		Function = function(callback)
			if callback then
				local floatTime = tick()
				AntiDeath:Clean(runService.PreSimulation:Connect(function()
					if not oldroot or not oldroot.Parent or not entitylib.isAlive then return end
	
					if (tick() - entitylib.character.AirTime) > 1.7 then
						floatTime = tick() + 0.2
					end
					oldroot.AssemblyLinearVelocity = Vector3.new(0, 1, 0)
					oldroot.CFrame = clone.CFrame - (tick() > floatTime and Vector3.new(0, 200, 0) or Vector3.zero)
				end))
	
				repeat
					if tick() > paused and entitylib.isAlive and (entitylib.character.Health / entitylib.character.MaxHealth) <= (Threshold.Value / 100) and (tick() - activated) >= Delay.Value then
						activated = tick()
						if Notify.Enabled then
							notif('AntiDeath', `Health below {Threshold.Value}%`, 12, 'warning')
						end
	
						if Mode.Value == 'Teleport' then
							lplr.Character.PrimaryPart.CFrame += Vector3.new(0, 100, 0)
							paused = tick() + 5
						elseif Mode.Value == 'Invincibility' and not store.rootpart and entitylib.isAlive and entitylib.character.Humanoid.Health > 0 and not (oldroot and oldroot.Parent) and lplr.Character.Parent then
							oldchar = lplr.Character
							oldroot = entitylib.character.HumanoidRootPart
							hip = entitylib.character.Humanoid.HipHeight
							oldchar.Parent = replicatedStorage
							clone = oldroot:Clone()
							clone.Parent = oldchar
							oldroot.Transparency = 1
							oldroot.Parent = workspace
							store.rootpart = oldroot
							oldchar.PrimaryPart = clone
							oldchar.Parent = workspace
							bedwars.QueryUtil:setQueryIgnored(clone, true)
							bedwars.QueryUtil:setQueryIgnored(oldroot, true)
							paused = tick() + 5
							task.delay(0, function()
								repeat task.wait() until not AntiDeath.Enabled or not entitylib.isAlive or (entitylib.character.Health / entitylib.character.MaxHealth) >= (StopThreshold.Value / 100)
								local old = clone and clone.CFrame or nil
								if destroyClone() and old then
									entitylib.character.RootPart.CFrame = old
								end
	
								paused = tick() + 5
	
								if AntiDeath.Enabled and Notify.Enabled then
									notif('AntiDeath', 'You are visible again', 12, 'info')
								end
							end)
						end
					end
					task.wait()
				until not AntiDeath.Enabled
			else
				destroyClone()
			end
		end,
		Tooltip = 'Uses selected mode when on a threshold'
	})
	
	Mode = AntiDeath:CreateDropdown({
		Name = 'Mode',
		List = {'Invincibility', 'Teleport'},
		Default = 'Invincibility',
		Tooltip = 'Teleport - Teleports you high up\nInvincibility - Makes you unhittable'
	})
	StopThreshold = AntiDeath:CreateSlider({
		Name = 'Stop Threshold',
		Min = 1,
		Max = 100,
		Default = 30,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Health percentage to untrigger at'
	})
	Threshold = AntiDeath:CreateSlider({
		Name = 'Threshold',
		Min = 1,
		Max = 100,
		Default = 30,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Health percentage to trigger at'
	})
	Delay = AntiDeath:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 20,
		Default = 5,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end,
		Tooltip = 'Delay between triggers'
	})
	Notify = AntiDeath:CreateToggle({
		Name = 'Notify on trigger',
		Default = true
	})
end)

local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local connection
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or not AntiFall.Enabled
				if not AntiFall.Enabled then return end

				local lowground, debounce = math.huge, tick()
				for _, v in bedwars.BlockController:getStore():getAllBlockPositions() do
					v = v * 3
					if v.Y < lowground and not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
						lowground = v.Y
					end
				end
				if lowground == math.huge then return end

				AntiFallPart = Instance.new('Part')
				AntiFallPart.Size = Vector3.new(10000, 1, 10000)
				AntiFallPart.Transparency = 1 - Color.Opacity
				AntiFallPart.Material = Enum.Material[Material.Value]
				AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				AntiFallPart.Position = Vector3.new(0, lowground - 2, 0)
				AntiFallPart.CanCollide = Mode.Value == 'Collide'
				AntiFallPart.Anchored = true
				AntiFallPart.CanQuery = false
				AntiFallPart.Parent = workspace
				AntiFall:Clean(AntiFallPart)
				AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
					if touched.Parent ~= lplr.Character or not entitylib.isAlive or debounce >= tick() then return end
					debounce = tick() + 0.1

					if Mode.Value == 'Normal' then
						local top = getNearGround()
						if not top then return end

						local lastTeleport = lplr:GetAttribute('LastTeleported')
						rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
						rayCheck.CollisionGroup = entitylib.character.RootPart.CollisionGroup
						if connection then
							connection:Disconnect()
						end
						connection = runService.PreSimulation:Connect(function()
							if vape.Modules.Fly.Enabled or vape.Modules.LongJump.Enabled or not entitylib.isAlive or lplr:GetAttribute('LastTeleported') ~= lastTeleport then
								connection:Disconnect()
								AntiFallDirection = nil
								return
							end

							local root = entitylib.character.RootPart
							local delta = (top - root.Position) * Vector3.new(1, 0, 1)
							AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
							root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)

							local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
							if ray then
								local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
								for _ = 1, 10 do
									if not getPlacedBlock(dpos) then
										top = Vector3.new(top.X, dpos.Y, top.Z)
										break
									end
									dpos += Vector3.new(0, 3, 0)
								end
							end

							root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
							if not frictionTable.Speed then
								root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
							end

							if delta.Magnitude < 1 then
								connection:Disconnect()
								AntiFallDirection = nil
							end
						end)
					elseif Mode.Value == 'Velocity' then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 100, root.AssemblyLinearVelocity.Z)
					end
				end))
			else
				if connection then
					connection:Disconnect()
					connection = nil
				end
				AntiFallDirection = nil
				AntiFallPart = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})

	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
		Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
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
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)

run(function()
	local AutoChargeProj
	local Percentage
	
	local old
	
	AutoChargeProj = vape.Categories.Blatant:CreateModule({
		Name = 'AutoChargeProj',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(self, launchdata, ...)
					local projmeta = bedwars.ProjectileMeta[launchdata.projectile]
					if projmeta and projmeta.predictionLifetimeSec and launchdata.drawDurationSeconds then
						launchdata.drawDurationSeconds = math.max(launchdata.drawDurationSeconds, projmeta.predictionLifetimeSec * (Percentage.Value / 100))
						launchdata.velocityMultiplier = math.max(launchdata.velocityMultiplier or 0, Percentage.Value / 100)
					end
					return old(self, launchdata, ...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
			end
		end,
		Tooltip = 'Instantly charges your projectile item to a certain percentage'
	})
	
	Percentage = AutoChargeProj:CreateSlider({
		Name = 'Percentage',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%'
	})
end)

run(function()
	local CannonSpeed
	local Value
	
	CannonSpeed = vape.Categories.Blatant:CreateModule({
		Name = 'CannonSpeed',
		Function = function(callback)
			debug.setconstant(bedwars.CannonHandController.launchSelf, 15, callback and Value.Value or 200)
		end,
		Tooltip = 'Makes you go faster with cannon.'
	})
	
	Value = CannonSpeed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 400,
		Function = function(val)
			if CannonSpeed.Enabled then
				debug.setconstant(bedwars.CannonHandController.launchSelf, 15, val)
			end
		end,
		Default = 200,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	CannonSpeed:CreateButton({
		Name = 'Sync to legit speed',
		Function = function()
			Value:SetValue(200)
		end
	})
end)

run(function()
	local DamageBoost
	local stack
	
	DamageBoost = vape.Categories.Blatant:CreateModule({
		Name = 'DamageBoost',
		Function = function(callback)
			if callback then
				DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if entitylib.isAlive and tick() > (stack or 0) and damageTable.entityInstance == lplr.Character and not vape.Modules.LongJump.Enabled then
						local horizontal = damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0
						knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = horizontal
						}).Magnitude * (0.9 + (store.ping.total or 0))
						stack = tick() + (knockbackSpeed / 45)
						knockbackBoost = tick() + (horizontal / 3.5)
					end
				end))
			end
		end,
		Tooltip = 'Makes you go slightly faster when damaged'
	})
end)

run(function()
	local DeathAdderAimbot
	local Mode
	local BedRange
	local Targets
	local Sort
	local TargetPart
	local FOV
	
	local old
	
	DeathAdderAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'DeathAdderAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.SorcererController.getProjectileDirection
				bedwars.SorcererController.getProjectileDirection = function(self, ...)
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local aim
						if Mode.Value == 'Bed' then
							local magnitude = BedRange.Value
							for _, v in collectionService:GetTagged('bed') do
								if not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
									local mag = (localPosition - v.Position).Magnitude
									if mag <= magnitude then
										aim, magnitude = v.Position, mag
									end
								end
							end
						else
							local ent = entitylib.EntityMouse({
								Range = FOV.Value,
								Part = 'RootPart',
								Wallcheck = Targets.Walls.Enabled,
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Priority = Targets.Priority.Value,
								Origin = localPosition,
								Sort = sortmethods[Sort.Value]
							})
							if ent then
								targetinfo.Targets[ent] = tick() + 1
								local tierdata = bedwars.SorcererBalance.getSorcererTierData(bedwars.SorcererBalance.getSorcererTier(lplr))
								local point = ent[TargetPart.Value].Position
								local speed = tierdata and tierdata.projectileVelocity or 70
								aim = point + (ent.RootPart.AssemblyLinearVelocity * ((point - localPosition).Magnitude / speed))
							end
						end
	
						if aim and aim ~= localPosition then
							return (aim - localPosition).Unit
						end
					end
	
					return old(self, ...)
				end
			else
				bedwars.SorcererController.getProjectileDirection = old
			end
		end,
		Tooltip = 'Silently aims Death Adder\'s spell at a bed or a player'
	})
	
	Mode = DeathAdderAimbot:CreateDropdown({
		Name = 'Mode',
		List = {'Player', 'Bed'},
		Function = function(val)
			if BedRange then
				BedRange.Object.Visible = val == 'Bed'
				FOV.Object.Visible = val == 'Player'
				TargetPart.Object.Visible = val == 'Player'
				Sort.Object.Visible = val == 'Player'
			end
		end,
		Tooltip = 'Bed aims at the closest enemy bed, Player leads the closest enemy'
	})
	BedRange = DeathAdderAimbot:CreateSlider({
		Name = 'Bed range',
		Min = 1,
		Max = 60,
		Default = 60,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Targets = DeathAdderAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = DeathAdderAimbot:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance',
		Darker = true
	})
	TargetPart = DeathAdderAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'},
		Darker = true
	})
	FOV = DeathAdderAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Darker = true
	})
end)

run(function()
	local FastBreak
	local BedCheck
	local HiveCheck
	local Blacklist
	local Blacklisted
	local Time
	
	local newlist, old = {}
	
	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, ...)
					local params = select(2, ...)
					pcall(function()
						local info = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = params})
						local block = info and info.target and info.target.blockInstance
						local blacklisted = false
						for _, v in block and Blacklist.Enabled and newlist or {} do
							if v == block.Name or block.Name:find(v) then
								blacklisted = true
								break
							end
						end
	
						if block and not blacklisted and (not BedCheck.Enabled or block.Name ~= 'bed') and (not HiveCheck.Enabled or block.Name ~= 'beehive') then
							bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
						end
					end)
	
					return old(self, ...)
				end
	
				repeat
					if (tick() - store.lastHit) > 0.3 then
						bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
					end
					task.wait(0.1)
				until not FastBreak.Enabled
			else
				bedwars.BlockBreaker.hitBlock = old
				bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	FastBreak:CreateButton({
		Name = 'Sync to legit speed',
		Function = function()
			Time:SetValue(0.3)
		end
	})
	BedCheck = FastBreak:CreateToggle({
		Name = 'Bed Check',
		Tooltip = 'Doesn\'t increase speed if ur breaking a bed'
	})
	HiveCheck = FastBreak:CreateToggle({
		Name = 'Blacklist Beehive',
		Tooltip = 'Doesn\'t increase speed if ur breaking a beehive'
	})
	Blacklist = FastBreak:CreateToggle({
		Name = 'Use blacklist',
		Function = function(callback)
			if Blacklisted then
				Blacklisted.Object.Visible = callback
			end
		end
	})
	Blacklisted = FastBreak:CreateTextList({
		Name = 'Blocks',
		Function = function(list)
			newlist = {}
			for _, v in list do
				if v:find('iron') then
					table.insert(newlist, 'iron_ore_mesh_block')
				else
					table.insert(newlist, v)
				end
			end
		end,
		Darker = true,
		Visible = false
	})
end)

local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				local tpTick, tpToggle, oldy = tick(), true

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end
				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not (vape.Modules.InfiniteFly or {}).Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 or store.matchState == 2
						local mass = (-0.02 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = moveDirection * math.max(Value.Value - velo, 0) * dt
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = (ray.Position + ray.Normal) - root.Position
							end
						end

						if not flyAllowed then
							if tpToggle and not oldy and (tick() - entitylib.character.AirTime) > 2 then
								local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
								if ray and TP.Enabled then
									tpToggle = false
									oldy = root.Position.Y
									tpTick = tick() + 0.11
									root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
								end
							elseif not tpToggle and oldy then
								if tpTick < tick() then
									root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, oldy, root.Position.Z), root.CFrame.LookVector)
									tpToggle = true
									oldy = nil
								else
									mass = 0
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))
				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})

	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
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
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
	})
end)

run(function()
	local Mode
	local Expand
	local objects, set = setmetatable({}, {__mode = 'k'})
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoved:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, v in entitylib.List do
						createHitbox(v)
					end
				end
			else
				if set then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
					set = nil
				end
				for _, v in objects do
					v:Destroy()
				end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
				else
					for _, v in objects do
						v.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Default = 14.4,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)

run(function()
	local Value
	local CameraDir
	local start
	local jumpTick, jumpSpeed, direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Handler:Get('ProjectileFire').Remote.instance
	end)
	
	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
	
			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
						switchItem(tool.tool)
					end
	
					bedwars.Handler:Get('AimCannon'):Fire('SendToServer', {
						cannonBlockPos = blockpos,
						lookVector = dir
					})
	
					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end
	
					task.delay(broken, function()
						for _ = 1, 3 do
							local call = bedwars.Handler:Get('LaunchSelfFromCannon'):Fire('CallServer', {cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								jumpSpeed = 5.25 * Value.Value
								jumpTick = tick() + 2.3
								direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				jumpSpeed = 4 * Value.Value
				jumpTick = tick() + 2.5
				direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
			end))
	
			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE', {disableBlockedAbilityAlert = true}) then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE', {disableBlockedAbilityAlert = true}) or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility('CAT_POUNCE', {disableBlockedAbilityAlert = true}) and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, pos, dir)
			if not pos then return end
	
			pos = pos - dir * 0.1
			local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -60, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
			switchItem(item.tool, 0)
			task.wait(0.1)
			if projectileRemote:InvokeServer(item.tool, 'fireball', 'fireball', shootPosition.Position, pos, shootPosition.LookVector * 60, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
				local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
				shoot = shoot and shoot[math.random(1, #shoot)] or nil
				if shoot then
					bedwars.AudioManager:playAudio(shoot)
				end
			end
		end,
		grappling_hook = function(item, pos, dir)
			if not pos then return end
	
			pos = pos - dir * 0.1
			local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -140, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
			switchItem(item.tool, 0)
			task.wait(0.1)
			if projectileRemote:InvokeServer(item.tool, 'grappling_hook_projectile', 'grappling_hook_projectile', shootPosition.Position, pos, shootPosition.LookVector * 140, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
				local shoot = bedwars.ItemMeta[item.itemType].projectileSource.launchSound
				shoot = shoot and shoot[math.random(1, #shoot)] or nil
				if shoot then
					bedwars.AudioManager:playAudio(shoot)
				end
			end
		end,
		jade_hammer = function(item, _, dir)
			local itemType = item.itemType:find('jade_hammer') and 'jade_hammer' or item.itemType
			if not bedwars.AbilityController:canUseAbility(itemType..'_jump', {disableBlockedAbilityAlert = true}) then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(itemType..'_jump', {disableBlockedAbilityAlert = true}) or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility(itemType..'_jump', {disableBlockedAbilityAlert = true}) and LongJump.Enabled then
				switchItem(item.tool, 0)
				lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				start += Vector3.new(0, 3.1, 0)
				task.wait(0.1)
				bedwars.AbilityController:useAbility(itemType..'_jump')
				jumpSpeed = 1.4 * Value.Value
				jumpTick = tick() + 2.5
				direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,
		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash', {disableBlockedAbilityAlert = true}) then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash', {disableBlockedAbilityAlert = true}) or not LongJump.Enabled
			end
	
			if LongJump.Enabled then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				jumpSpeed = 4.5 * Value.Value
				jumpTick = tick() + 2.4
				direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end
	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						local boost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1
	
						if boost >= jumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
							if not pos then return end
							local vec = (entitylib.character.RootPart.Position - pos)
							jumpSpeed = boost
							jumpTick = tick() + 2.5
							direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))
				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						jumpSpeed = 2.5 * Value.Value
						jumpTick = tick() + 2.5
						direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))
	
				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
					if root and isnetworkowner(root) then
						if jumpTick > tick() then
							local speed = getSpeed()
							local destination = (direction * math.max(((jumpTick - tick()) > 1.1 and jumpSpeed or 0), 0) * dt)
							root.CFrame += destination
							root.AssemblyLinearVelocity = (direction * speed) + Vector3.new(0, 15, 0)
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							jumpSpeed = 0
						end
					else
						start = nil
					end
				end))
	
				if store.hand and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end
	
				for i, v in LongJumpMethods do
					local item = getItem(i, nil, true)
					if item or store.equippedKit == i then
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
			else
				jumpTick = tick()
				direction = nil
				jumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Lets you jump farther'
	})
	
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)

run(function()
	local MultiJump
	local Jumps
	local Delay
	local Auto
	local Ground
	
	local Request = bedwars.Handler:Get('NotifyAirJump')
	local groundCheck = RaycastParams.new()
	groundCheck.FilterType = Enum.RaycastFilterType.Exclude
	local jumped, lastJump = 0, 0
	
	MultiJump = vape.Categories.Blatant:CreateModule({
		Name = 'MultiJump',
		Function = function(callback)
			if callback then
				jumped, lastJump = 0, 0
	
				MultiJump:Clean(inputService.JumpRequest:Connect(function()
					if Auto.Enabled or not entitylib.isAlive or jumped >= Jumps.Value or tick() - lastJump < Delay.Value then return end
					local humanoid = entitylib.character.Humanoid
					if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then return end
	
					jumped += 1
					lastJump = tick()
					humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					Request:Fire('SendToServer')
				end))
	
				repeat
					if entitylib.isAlive then
						local humanoid = entitylib.character.Humanoid
						local state = humanoid:GetState()
						if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
							jumped = 0
						elseif Auto.Enabled and state == Enum.HumanoidStateType.Freefall and jumped < Jumps.Value and tick() - lastJump >= Delay.Value and entitylib.character.RootPart.AssemblyLinearVelocity.Y <= 0 then
							groundCheck.FilterDescendantsInstances = {lplr.Character}
							if not Ground.Enabled or not entitylib.Raycast(entitylib.character.RootPart.Position, Vector3.new(0, -12, 0), groundCheck) then
								jumped += 1
								lastJump = tick()
								humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
								Request:Fire('SendToServer')
							end
						end
					end
					task.wait()
				until not MultiJump.Enabled
			end
		end,
		Tooltip = 'Lets you jump again in mid air, the game only gates this on your own client'
	})
	
	Jumps = MultiJump:CreateSlider({
		Name = 'Jumps',
		Min = 1,
		Max = 20,
		Default = 2,
		Suffix = function(val)
			return val <= 1 and 'jump' or 'jumps'
		end,
		Tooltip = 'Extra jumps you get before touching the ground again'
	})
	Delay = MultiJump:CreateSlider({
		Name = 'Delay',
		Min = 0.05,
		Max = 1,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds',
		Tooltip = 'Spacing between air jumps, the game uses 0.25'
	})
	Auto = MultiJump:CreateToggle({
		Name = 'Auto jump',
		Function = function(callback)
			if Ground then
				Ground.Object.Visible = callback
			end
		end,
		Tooltip = 'Jumps on its own while you are falling instead of waiting for your jump key'
	})
	Ground = MultiJump:CreateToggle({
		Name = 'Ground check',
		Default = true,
		Visible = false,
		Tooltip = 'Saves the auto jumps for when there is nothing under you'
	})
end)

run(function()
	local NoFall
	local Damage
	local disabled = setmetatable({}, {__mode = 'k'})
	local groundHit = bedwars.Handler:Get('GroundHit')
	
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				local humanoid = entitylib.isAlive and entitylib.character.Humanoid
				if humanoid and not disabled[humanoid] and getconnections then
					disabled[humanoid] = {}
					for _, v in getconnections(humanoid.StateChanged) do
						v:Disable()
						table.insert(disabled[humanoid], v)
					end
				end
	
				local tracked = 0
				NoFall:Clean(runService.PostSimulation:Connect(function()
					if entitylib.isAlive and store.matchState == 1 and not store.infinitefly then
						local root = entitylib.character.RootPart
						local velo = root.AssemblyLinearVelocity
	
						if tracked < -(45 + (Damage.Value * 0.75)) then
							root.AssemblyLinearVelocity = Vector3.new(0, 2.5, 0)
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Landed)
							runService.PreRender:Wait()
							root.AssemblyLinearVelocity = velo
							groundHit:Fire('SendToServer', nil, Vector3.new(0, tracked, 0), workspace:GetServerTimeNow())
						end
						tracked = velo.Y
					else
						tracked = 0
					end
				end))
	
				NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					if ent.Humanoid:WaitForChild('Animator', 5) then
						task.wait(0.5)
						if NoFall.Enabled and not disabled[ent.Humanoid] and getconnections then
							disabled[ent.Humanoid] = {}
							for _, v in getconnections(ent.Humanoid.StateChanged) do
								v:Disable()
								table.insert(disabled[ent.Humanoid], v)
							end
						end
					end
				end))
			else
				for _, v in disabled do
					for _, v2 in v do
						v2:Enable()
					end
				end
	
				table.clear(disabled)
			end
		end,
		Tooltip = 'Prevents taking fall damage.'
	})
	
	Damage = NoFall:CreateSlider({
		Name = 'Damage',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%',
		Tooltip = 'How much of each fall lands on you, it only starts saving you once you are dropping faster than this lets through'
	})
end)

run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlow',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if tab.moveSpeedMultiplier then
						tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
					end
					return old(self, tab)
				end
	
				for i in modifier.modifiers do
					if (i.moveSpeedMultiplier or 1) < 1 then
						modifier:removeModifier(i)
					end
				end
			else
				modifier.addModifier = old
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)

run(function()
	local OwlAura
	local Targets
	local Mode
	local Range
	
	OwlAura = vape.Categories.Blatant:CreateModule({
		Name = 'OwlAura',
		Function = function(callback)
			if callback then
				local owls = collection('Owl', OwlAura, function(tab, obj)
					task.delay(1, function()
						if obj and obj.Parent and obj:GetAttribute('Owner') == lplr.UserId then
							table.insert(tab, obj)
						end
					end)
				end)
				repeat
					if store.equippedKit ~= 'owl' then
						task.wait(1)
						continue
					end
	
					if entitylib.isAlive then
						local owl = owls[1]
						if owl then
							local origin = owl.Part.Position
							local plr = entitylib.EntityPosition({
								Origin = origin,
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Priority = Targets.Priority.Value,
								Wallcheck = Targets.Walls.Enabled,
								Sort = sortmethods[Mode.Value]
							})
	
							if plr then
								local meta = bedwars.ProjectileMeta.owl_projectile
								local targetVelocity = plr.RootPart.AssemblyLinearVelocity
								local targetAirborne = plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
								local calc, _, travelTime = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, plr.RootPart.Position, targetVelocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil, store.airRay, targetAirborne, plr.RootPart.Position, plr.RootPart, nil, true)
								if calc and travelTime and travelTime <= (meta.lifetimeSec or 3) then
									local dir = CFrame.lookAt(origin, calc).LookVector * meta.launchVelocity
									bedwars.Handler:Get('OwlAiming'):Fire('SendToServer', {
										owl = owl.Part,
										starting = true
									})
									bedwars.Handler:Get('OwlFireProjectile'):Fire('SendToServer', {
										ProjectileRefId = httpService:GenerateGUID(true),
										direction = dir,
										fromPosition = origin,
										initialVelocity = dir
									})
									task.wait(store.ping.total or 0)
								end
							end
						end
					end
					task.wait(0.1)
				until not OwlAura.Enabled
			else
				bedwars.Handler:Get('OwlAiming'):Fire('SendToServer', {starting = false})
			end
		end,
		Tooltip = 'Automatically shoots projectiles with whisper kit'
	})
	
	Targets = OwlAura:CreateTargets({
		Players = true,
		Wallcheck = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Mode = OwlAura:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance'
	})
	Range = OwlAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local TargetPart
	local Targets
	local Sort
	local FOV
	local Horizontal
	local Vertical
	local AutoCharge
	local Aim = {}
	local OtherProjectiles
	local Blacklist
	local old
	local arcCheck = RaycastParams.new()
	arcCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				local function aimLaunchValues(self, projmeta, worldmeta, origin, shootpos)
					local pos = shootpos or self:getLaunchPosition(origin)
					if not pos then
						return
					end
	
					if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
						return
					end
	
					if table.find(Blacklist.ListEnabled or {}, ((projmeta.projectile == 'glue_trap' or projmeta.projectile == 'glue_projectile') and 'gloop' or projmeta.projectile)) then
						return
					end
	
					local meta = projmeta:getProjectileMeta()
					local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
					local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
					local projSpeed = (meta.launchVelocity or 100)
					local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
					local part = TargetPart.Value == 'Dynamic' and (store.hand.tool and store.hand.tool.Name:find('headhunter') and 'Head' or 'RootPart') or TargetPart.Value
	
					local function getLaunchValues(plr)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity
	
						if balloons and balloons > 0 then
							playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
						end
	
						if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end
	
						if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
							for _, v in collectionService:GetTagged('Owl') do
								if v:GetAttribute('Target') == plr.Player.UserId and v:GetAttribute('Status') == 2 then
									playerGravity = 0
								end
							end
						end
	
						local aimpart = getTargetPart(plr, part)
						local velocity = projmeta.projectile == 'telepearl' and Vector3.zero or aimpart.AssemblyLinearVelocity
						local airborne = plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(plr.RootPart.AssemblyLinearVelocity.Y) > 0.01
						local newlook = CFrame.new(offsetpos, aimpart.Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
						local calc, _, travelTime = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, aimpart.Position, velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, store.airRay, airborne, plr.RootPart.Position, plr.RootPart, nil, true)
						if calc and travelTime and (Horizontal.Value ~= 1 or Vertical.Value ~= 1) then
							local rise = (velocity.Y * travelTime) - (playerGravity * travelTime * travelTime * 0.5)
							local lead = Vector3.new(velocity.X * travelTime * (Horizontal.Value - 1), rise * (Vertical.Value - 1), velocity.Z * travelTime * (Horizontal.Value - 1))
							local adjusted, _, adjustedTime = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, aimpart.Position + lead, velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, store.airRay, airborne, plr.RootPart.Position, plr.RootPart, nil, true)
							if adjusted then
								calc, travelTime = adjusted, adjustedTime or travelTime
							end
						end
	
						if not calc then
							return nil
						end
	
						store.hitchance.ProjectileAimbot = {Value = getHitChance(plr, travelTime), Clock = tick()}
						local launch = CFrame.new(newlook.Position, calc).LookVector * projSpeed
						if Targets.Walls.Enabled and travelTime then
							local ignorelist = {gameCamera, lplr.Character}
							for _, v in entitylib.List do
								if v.Character then
									table.insert(ignorelist, v.Character)
								end
							end
							arcCheck.FilterDescendantsInstances = ignorelist
							if not prediction.IsTrajectoryClear(offsetpos, launch, gravity, travelTime, arcCheck) then
								return nil
							end
						end
	
						return {
							initialVelocity = launch * ((AutoCharge.Enabled or not Aim.Enabled) and 1 or projmeta.velocityMultiplier),
							positionFrom = offsetpos,
							deltaT = lifetime,
							gravitationalAcceleration = gravity,
							drawDurationSeconds = AutoCharge.Enabled and 5 or projmeta.drawDurationSeconds
						}
					end
	
					local values, attempts, started = nil, 0, os.clock()
					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero,
						MouseOrigin = gameCamera.ViewportSize / 2,
						Sort = sortmethods[Sort.Value],
						Check = function(entity)
							if attempts >= 10 or (attempts > 0 and (os.clock() - started) > 0.0015) then
								return false
							end
							attempts += 1
							values = getLaunchValues(entity)
							return values ~= nil
						end
					})
	
					if plr and values then
						targetinfo.Targets[plr] = tick() + 1
						return values
					end
				end
	
				bedwars.ProjectileController.calculateImportantLaunchValues = function(self, projmeta, worldmeta, origin, shootpos, ...)
					local success, values = pcall(aimLaunchValues, self, projmeta, worldmeta, origin, shootpos)
					if success and values then
						return values
					end
	
					return old(self, projmeta, worldmeta, origin, shootpos, ...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = ProjectileAimbot:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance'
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'},
		Tooltip = 'Dynamic aims at the head with a headhunter, since that is the only bow that pays extra for one, and at the body with everything else'
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	Horizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim sideways'
	})
	Vertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'Scales how far ahead of the target you aim while it rises or falls'
	})
	AutoCharge = ProjectileAimbot:CreateToggle({
		Name = 'Auto Charge',
		Function = function(callback)
			if Aim.Object then
				Aim.Object.Visible = callback
			end
		end,
		Default = true,
		Tooltip = 'Fully charges your bow, Allowing your projectile to deal more damage'
	})
	Aim = ProjectileAimbot:CreateToggle({
		Name = 'Aim change',
		Default = true,
		Darker = true,
		Tooltip = 'Changes your trajectory to match charge percentage.'
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Default = {'telepearl'}
	})
end)

run(function()
	local ProjectileAura
	local Targets
	local Part
	local FireRate
	local Range
	local AFKCheck
	local List
	local UseSophia
	local UseWhim
	local UseNazar
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = bedwars.Handler:Get('ProjectileFire').Remote.instance
	end)
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 and (not AFKCheck.Enabled or not isAfk()) then
						local ent = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent then
							local localPosition = entitylib.character.RootPart.Position
							for _, v in getProjectiles(List.ListEnabled, UseSophia.Enabled, UseWhim.Enabled, UseNazar.Enabled) do
								local item, ammo, projectile, itemMeta = unpack(v)
								local aimpart = getTargetPart(ent, Part.Value == 'Dynamic' and (item.itemType:find('headhunter') and 'Head' or 'RootPart') or Part.Value)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local targetVelocity = ent.RootPart.AssemblyLinearVelocity
									local targetAirborne = ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(targetVelocity.Y) > 0.01
									local calc = prediction.SolveTrajectory(localPosition, projSpeed, gravity, aimpart.Position, targetVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, targetAirborne, ent.RootPart.Position, ent.RootPart, nil, true)
									if calc then
										local switched = switchItem(item.tool)
	
										targetinfo.Targets[ent] = tick() + 1
	
										task.spawn(function()
											local shootPosition = (CFrame.new(localPosition, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											local aim, _, flight = prediction.SolveTrajectory(shootPosition, projSpeed, gravity, aimpart.Position, targetVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck, targetAirborne, ent.RootPart.Position, ent.RootPart, nil, true)
											store.hitchance.ProjectileAura = {Value = getHitChance(ent, flight), Clock = tick()}
											aim = aim or calc
											local dir, id = CFrame.lookAt(shootPosition, aim).LookVector, httpService:GenerateGUID(true)
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, localPosition, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											prediction.trackShot(ent.RootPart)
											expectKnockback(ent.RootPart, flight, shootPosition, itemMeta.knockback)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.AudioManager:playAudio(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + itemMeta.fireDelaySec
										if switched then
											task.wait(FireRate:GetRandomValue())
										end
									end
								end
							end
						end
					end
					task.wait(0.03)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you'
	})
	
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	Part = ProjectileAura:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'},
		Tooltip = 'Dynamic aims at the head with a headhunter, since that is the only bow that pays extra for one, and at the body with everything else'
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	UseSophia = ProjectileAura:CreateToggle({
		Name = 'Use sophia',
		Tooltip = 'Also shoots sophia\'s frost staff, swapping it out of mist mode on its own'
	})
	UseWhim = ProjectileAura:CreateToggle({
		Name = 'Use whim',
		Tooltip = 'Also casts whim\'s magic book, follows whatever element you have cycled'
	})
	UseNazar = ProjectileAura:CreateToggle({
		Name = 'Use nazar',
		Tooltip = 'Also shoots nazar\'s life bow, crossbow and headhunter'
	})
	FireRate = ProjectileAura:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	AFKCheck = ProjectileAura:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops firing once you have not touched your mouse or keyboard for 30 seconds'
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local Speed
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local modifier = {}
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			local blatant = callback and Mode.Value == 'Blatant'
			frictionTable.Speed = blatant or nil
			updateVelocity()
			debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, blatant and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			bedwars.StatefulEntityKnockbackController.lastImpulseTime = blatant and math.huge or time()
	
			if callback then
				if not blatant then
					modifier.moveSpeedMultiplier = Value.Value / 20
					local handle = bedwars.SprintController:getMovementStatusModifier():addModifier(modifier)
					Speed:Clean(function()
						handle:Destroy()
					end)
				end
	
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if blatant then
						bedwars.StatefulEntityKnockbackController.lastImpulseTime = math.huge
					end
					if entitylib.isAlive and not Fly.Enabled and not LongJump.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
						if blatant then
							local root, velo = entitylib.character.RootPart, getSpeed()
							local destination = moveDirection * math.max(Value.Value - velo, 0) * dt
							if WallCheck.Enabled then
								rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
								rayCheck.CollisionGroup = root.CollisionGroup
								local ray = workspace:Raycast(root.Position, destination, rayCheck)
								if ray then
									destination = (ray.Position + ray.Normal) - root.Position
								end
							end
	
							root.CFrame += destination
							root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						end
						if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (store.attacking or AlwaysJump.Enabled) then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = {'Blatant', 'Legit'},
		Function = function(val)
			if WallCheck then
				WallCheck.Object.Visible = val == 'Blatant'
			end
			if Speed.Enabled then
				Speed:Toggle()
				Speed:Toggle()
			end
		end,
		Default = 'Blatant',
		Tooltip = 'Blatant - Heatseeker, moves your root forward every frame\nLegit - Raises your walkspeed through the games own speed system'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Function = function(val)
			if Speed.Enabled and Mode.Value == 'Legit' then
				modifier.moveSpeedMultiplier = val / 20
				bedwars.SprintController:getMovementStatusModifier():updateModifiers()
			end
		end,
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)

run(function()
	local TerraAimbot
	local Targets
	local Sort
	local TargetPart
	local FOV
	local Horizontal
	local Vertical
	local old
	local arcCheck = RaycastParams.new()
	arcCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	TerraAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'TerraAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.BlockKickerKitController.onAbilityUsed
				bedwars.BlockKickerKitController.onAbilityUsed = function(self, character, data, ...)
					if not data or data.ability ~= 'BLOCK_KICK' or not entitylib.isAlive then
						return old(self, character, data, ...)
					end
	
					local look = gameCamera.CFrame.LookVector
					local origin = self:getKickBlockProjectileOriginPosition(entitylib.character.RootPart.Position, look)
					local part = TargetPart.Value
					local aim
	
					local ent = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Origin = origin,
						MouseOrigin = gameCamera.ViewportSize / 2,
						Sort = sortmethods[Sort.Value],
						Check = function(entity)
							local aimpart = getTargetPart(entity, part)
							local velocity = aimpart.AssemblyLinearVelocity
							local playerGravity = workspace.Gravity
							local balloons = entity.Character:GetAttribute('InflatedBalloons')
							if balloons and balloons > 0 then
								playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
							end
	
							local airborne = entity.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(entity.RootPart.AssemblyLinearVelocity.Y) > 0.01
							local calc, _, travelTime = prediction.SolveTrajectory(origin, 100, 20, aimpart.Position, velocity, playerGravity, entity.HipHeight, entity.Jumping and 42.6 or nil, store.airRay, airborne, entity.RootPart.Position, entity.RootPart, nil, true)
							if calc and travelTime and (Horizontal.Value ~= 1 or Vertical.Value ~= 1) then
								local rise = (velocity.Y * travelTime) - (playerGravity * travelTime * travelTime * 0.5)
								local lead = Vector3.new(velocity.X * travelTime * (Horizontal.Value - 1), rise * (Vertical.Value - 1), velocity.Z * travelTime * (Horizontal.Value - 1))
								local adjusted, _, adjustedTime = prediction.SolveTrajectory(origin, 100, 20, aimpart.Position + lead, velocity, playerGravity, entity.HipHeight, entity.Jumping and 42.6 or nil, store.airRay, airborne, entity.RootPart.Position, entity.RootPart, nil, true)
								if adjusted then
									calc, travelTime = adjusted, adjustedTime or travelTime
								end
							end
							if not calc or (calc - origin).Magnitude <= 0 then return false end
	
							if Targets.Walls.Enabled and travelTime then
								local ignorelist = {gameCamera, lplr.Character}
								for _, v in entitylib.List do
									if v.Character then
										table.insert(ignorelist, v.Character)
									end
								end
								arcCheck.FilterDescendantsInstances = ignorelist
								if not prediction.IsTrajectoryClear(origin, (calc - origin).Unit * 100, 20, travelTime, arcCheck) then
									return false
								end
							end
	
							store.hitchance.TerraAimbot = {Value = getHitChance(entity, travelTime), Clock = tick()}
							aim = (calc - origin).Unit
							return true
						end
					})
	
					if not ent or not aim then
						return old(self, character, data, ...)
					end
	
					targetinfo.Targets[ent] = tick() + 1
					if bedwars.CameraPerspectiveController:getCameraPerspective() == 1 then
						local scale = ((0.7 * aim.Y) + math.sqrt((0.49 * aim.Y * aim.Y) + 3.51)) / 2
						aim = (aim * scale) - Vector3.new(0, 0.35, 0)
					end
	
					local restore = gameCamera.CFrame
					gameCamera.CFrame = CFrame.lookAt(restore.Position, restore.Position + aim)
					local call = old(self, character, data, ...)
					gameCamera.CFrame = restore
					return call
				end
			else
				bedwars.BlockKickerKitController.onAbilityUsed = old
			end
		end,
		Tooltip = 'Silently aims Terra\'s block kick at the enemy'
	})
	
	Targets = TerraAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = TerraAimbot:CreateDropdown({
		Name = 'Target mode',
		List = methods
	})
	TargetPart = TerraAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random'}
	})
	FOV = TerraAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	Horizontal = TerraAimbot:CreateSlider({
		Name = 'Horizontal prediction',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Default = 1,
		Tooltip = 'How much of the targets sideways movement to lead, 1 is the honest amount'
	})
	Vertical = TerraAimbot:CreateSlider({
		Name = 'Vertical prediction',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Default = 1,
		Tooltip = 'How much of the targets rise and fall to lead, 1 is the honest amount'
	})
end)

run(function()
	local ArmorChanger
	local Trim
	local Color
	local Effect
	local Rank
	local added = {}
	local trims, colors, effects = {}, {}, {}
	local trimvalues, colorvalues, effectvalues = {}, {}, {}
	
	for _, v in bedwars.ArmorTrimType do
		local meta = bedwars.ArmorTrimMeta[v]
		local label = meta and meta.name or (tostring(v):gsub('_', ' '):gsub('%a+', function(word)
			return word:sub(1, 1):upper()..word:sub(2):lower()
		end))
		if trimvalues[label] == nil then
			trimvalues[label] = v
			table.insert(trims, label)
		end
	end
	table.sort(trims)
	
	for i, v in bedwars.ArmorTrimColor do
		local label = (tostring(i):gsub('_', ' '):gsub('%a+', function(word)
			return word:sub(1, 1):upper()..word:sub(2):lower()
		end))
		if colorvalues[label] == nil then
			colorvalues[label] = v
			table.insert(colors, label)
		end
	end
	table.sort(colors)
	
	for _, v in bedwars.ArmorTrimEffectType do
		local meta = bedwars.ArmorTrimEffectMeta[v]
		local label = meta and meta.name or (tostring(v):gsub('_', ' '):gsub('%a+', function(word)
			return word:sub(1, 1):upper()..word:sub(2):lower()
		end))
		if effectvalues[label] == nil then
			effectvalues[label] = v
			table.insert(effects, label)
		end
	end
	table.sort(effects)
	
	local function applyTrim()
		for _, v in added do
			if v.Parent then
				v:Destroy()
			end
		end
		table.clear(added)
		if not ArmorChanger.Enabled or not lplr.Character then return end
	
		local trim = trimvalues[Trim.Value]
		local color = colorvalues[Color.Value]
		local effect = effectvalues[Effect.Value]
		if not trim or not color or not effect then return end
	
		local before = {}
		for _, v in lplr.Character:GetDescendants() do
			before[v] = true
		end
	
		bedwars.ArmorTrimController:attachArmorTrimEffects(lplr.Character, trim, color, Rank.Value - 1, effect)
	
		for _, v in lplr.Character:GetDescendants() do
			if not before[v] then
				table.insert(added, v)
			end
		end
	end
	
	ArmorChanger = vape.Categories.Render:CreateModule({
		Name = 'ArmorChanger',
		Function = function(callback)
			if callback then
				ArmorChanger:Clean(lplr.CharacterAdded:Connect(function()
					task.wait(1)
					applyTrim()
				end))
				ArmorChanger:Clean(function()
					for _, v in added do
						if v.Parent then
							v:Destroy()
						end
					end
					table.clear(added)
				end)
			end
			applyTrim()
		end,
		Tooltip = 'Puts an armor trim on yourself, only you can see it'
	})
	
	Trim = ArmorChanger:CreateDropdown({
		Name = 'Trim',
		List = trims,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end
	})
	Color = ArmorChanger:CreateDropdown({
		Name = 'Color',
		List = colors,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end
	})
	Effect = ArmorChanger:CreateDropdown({
		Name = 'Effect',
		List = effects,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end
	})
	Rank = ArmorChanger:CreateSlider({
		Name = 'Tier',
		Min = 1,
		Max = 7,
		Function = function()
			if ArmorChanger.Enabled then
				applyTrim()
			end
		end,
		Default = 7,
		Suffix = function(val)
			local meta = bedwars.ArmorTrimEffectRankMeta[val - 1]
			return meta and meta.tier and (tostring(meta.tier):gsub('_', ' '):gsub('%a+', function(word)
				return word:sub(1, 1):upper()..word:sub(2):lower()
			end)) or ''
		end,
		Tooltip = 'Higher tiers use the fancier version of the effect'
	})
end)

run(function()
	local BedESP
	local Reference = setmetatable({}, {__mode = 'k'})
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, v in parts do
			if v:IsA('BasePart') and v.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = v.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = v
				handle.Color3 = v.Color
				if v.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = v.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, v in collectionService:GetTagged('bed') do
					Added(v)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)

run(function()
	local HiveESP
	local Color
	local Transparency
	local Scale
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		local userid = ent:GetAttribute('PlacedByUserId')
		local placer = userid and playersService:GetPlayerByUserId(userid)
		local name = placer and placer.Name
		if not name and userid then
			local suc, res = pcall(playersService.GetNameFromUserIdAsync, playersService, userid)
			name = suc and res or nil
		end
	
		local level = ent:GetAttribute('Level') or 0
		local nametag = Instance.new('TextLabel')
		nametag.Name = name or 'Unknown'
		nametag.Text = `{nametag.Name}'s beehive | {level} Bee{level >= 2 and 's' or ''}`
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local size = getfontbounds(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace)
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Transparency.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end
	
	HiveESP = vape.Categories.Render:CreateModule({
		Name = 'BeehiveESP',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('beehive') do
					Added(v)
				end
				HiveESP:Clean(collectionService:GetInstanceAddedSignal('beehive'):Connect(Added))
				HiveESP:Clean(collectionService:GetInstanceRemovedSignal('beehive'):Connect(function(ent)
					if Reference[ent] then
						Reference[ent]:Destroy()
						Reference[ent] = nil
					end
				end))
				HiveESP:Clean(runService.PreRender:Connect(function()
					for i, v in Reference do
						if not i.Parent then
							v:Destroy()
							Reference[i] = nil
							continue
						end
	
						local screenPos, visible = gameCamera:WorldToViewportPoint(i.Position + Vector3.new(0, 1, 0))
						v.Visible = visible
						if not visible then continue end
	
						local level = i:GetAttribute('Level') or 0
						local text = `{v.Name}'s beehive | {level} Bee{level >= 2 and 's' or ''}`
						if v.Text ~= text then
							v.Text = text
							local size = getfontbounds(removeTags(text), v.TextSize, v.FontFace)
							v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						end
						v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
					end
				end))
			else
				for i, v in Reference do
					v:Destroy()
					Reference[i] = nil
				end
			end
		end,
		Tooltip = 'Renders hives locations and info'
	})
	
	Color = HiveESP:CreateColorSlider({
		Name = 'Text Color',
		Function = function(hue, sat, val)
			if not HiveESP.Enabled then return end
			for _, v in Reference do
				v.TextColor3 = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Transparency = HiveESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(value)
			if not HiveESP.Enabled then return end
			for _, v in Reference do
				v.BackgroundTransparency = value
			end
		end,
		Default = 0.5
	})
	Scale = HiveESP:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = function(value)
			if not HiveESP.Enabled then return end
			for _, v in Reference do
				v.TextSize = 14 * value
				local size = getfontbounds(removeTags(v.Text), v.TextSize, v.FontFace)
				v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			end
		end,
		Default = 1
	})
end)

run(function()
	local Clouds
	local Scale
	local CloudColor
	local folder, folderConnection
	local reference = setmetatable({}, {__mode = 'k'})
	
	local function applyAll()
		if not Clouds.Enabled or not folder then return end
		for _, v in folder:GetChildren() do
			if v:IsA('BasePart') then
				if not reference[v] then
					reference[v] = {v.Size, v.Color, v.Transparency}
				end
				v.Size = reference[v][1] * (Scale.Value / 100)
				v.Color = Color3.fromHSV(CloudColor.Hue, CloudColor.Sat, CloudColor.Value)
				v.Transparency = 1 - CloudColor.Opacity
			end
		end
	end
	
	local function bindFolder(new)
		if folderConnection then
			folderConnection:Disconnect()
			folderConnection = nil
		end
	
		folder = new
		if not folder then return end
	
		folderConnection = folder.ChildAdded:Connect(function(part)
			task.defer(function()
				if not Clouds.Enabled or not part:IsA('BasePart') then return end
				if not reference[part] then
					reference[part] = {part.Size, part.Color, part.Transparency}
				end
				part.Size = reference[part][1] * (Scale.Value / 100)
				part.Color = Color3.fromHSV(CloudColor.Hue, CloudColor.Sat, CloudColor.Value)
				part.Transparency = 1 - CloudColor.Opacity
			end)
		end)
		applyAll()
	end
	
	Clouds = vape.Categories.Render:CreateModule({
		Name = 'Clouds',
		Function = function(callback)
			if callback then
				Clouds:Clean(workspace.ChildAdded:Connect(function(child)
					if child.Name == 'Clouds' then
						bindFolder(child)
					end
				end))
				bindFolder(workspace:FindFirstChild('Clouds'))
			else
				bindFolder(nil)
				for i, v in reference do
					if i.Parent then
						i.Size = v[1]
						i.Color = v[2]
						i.Transparency = v[3]
					end
				end
				table.clear(reference)
			end
		end,
		Tooltip = 'Restyles the clouds around the map'
	})
	
	Scale = Clouds:CreateSlider({
		Name = 'Size',
		Min = 5,
		Max = 300,
		Function = applyAll,
		Default = 100,
		Suffix = function()
			return '%'
		end
	})
	CloudColor = Clouds:CreateColorSlider({
		Name = 'Color',
		DefaultSat = 0,
		Darker = true,
		Function = applyAll
	})
end)

run(function()
	local CollectableESP
	local Collectables
	local Distance
	local Transparency
	local Scale
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local tags = {
		['alchemist_ingedients'] = 'Ingredient',
		['alchemy_crystal'] = 'Crystal',
		['crystalheart_seed'] = 'Crystalheart',
		['forest_environment_plant'] = 'Plant',
		['ghost'] = 'Ghost',
		['hidden-metal'] = 'Metal',
		['jailor_soul'] = 'Soul',
		['murder_coin'] = 'Coin',
		['shadow_coin'] = 'Shadow Coin',
		['soulvine_seed'] = 'Soulvine',
		['spirit_gardener_energy'] = 'Energy',
		['spirit_gardener_seeds'] = 'Seed',
		['stars'] = 'Star',
		['tearbloom_seed'] = 'Tearbloom'
	}
	
	local function Added(obj, tag)
		if Reference[obj] or not table.find(Collectables.ListEnabled, tags[tag]) then return end
	
		local nametag = Instance.new('TextLabel')
		nametag.Name = tags[tag]
		nametag.Text = tags[tag]
		nametag.TextSize = 14 * Scale.Value
		nametag.FontFace = uipallet.Font
		local size = getfontbounds(nametag.Text, nametag.TextSize, nametag.FontFace)
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Transparency.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.Parent = Folder
		Reference[obj] = nametag
	end
	
	CollectableESP = vape.Categories.Render:CreateModule({
		Name = 'CollectableESP',
		Function = function(callback)
			if callback then
				for i in tags do
					for _, v in collectionService:GetTagged(i) do
						Added(v, i)
					end
					CollectableESP:Clean(collectionService:GetInstanceAddedSignal(i):Connect(function(obj)
						Added(obj, i)
					end))
					CollectableESP:Clean(collectionService:GetInstanceRemovedSignal(i):Connect(function(obj)
						if Reference[obj] then
							Reference[obj]:Destroy()
							Reference[obj] = nil
						end
					end))
				end
	
				CollectableESP:Clean(runService.PreRender:Connect(function()
					local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position
					for i, v in Reference do
						local part = i:IsA('Model') and i.PrimaryPart or i
						if not i.Parent or not part then
							v:Destroy()
							Reference[i] = nil
							continue
						end
	
						local screenPos, visible = gameCamera:WorldToViewportPoint(part.Position + Vector3.new(0, 2, 0))
						v.Visible = visible
						if not visible then continue end
	
						local text = Distance.Enabled and localPosition and `{v.Name} | {((localPosition - part.Position).Magnitude) // 1}m` or v.Name
						if v.Text ~= text then
							v.Text = text
							local size = getfontbounds(text, v.TextSize, v.FontFace)
							v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						end
						v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
					end
				end))
			else
				for i, v in Reference do
					v:Destroy()
					Reference[i] = nil
				end
			end
		end,
		Tooltip = 'Renders every kit collectable in the map, they have no nametag of their own'
	})
	
	Distance = CollectableESP:CreateToggle({
		Name = 'Distance',
		Default = true
	})
	Scale = CollectableESP:CreateSlider({
		Name = 'Scale',
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Function = function(value)
			for _, v in Reference do
				v.TextSize = 14 * value
				local size = getfontbounds(v.Text, v.TextSize, v.FontFace)
				v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			end
		end
	})
	Transparency = CollectableESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimal = 100,
		Function = function(value)
			for _, v in Reference do
				v.BackgroundTransparency = value
			end
		end
	})
	Color = CollectableESP:CreateColorSlider({
		Name = 'Text Color',
		Function = function(hue, sat, val)
			for _, v in Reference do
				v.TextColor3 = Color3.fromHSV(hue, sat, val)
			end
		end,
		Darker = true
	})
	Collectables = CollectableESP:CreateTextList({
		Name = 'Collectables',
		Function = function()
			if CollectableESP.Enabled then
				CollectableESP:Toggle()
				CollectableESP:Toggle()
			end
		end,
		Default = {
			'Coin',
			'Crystal',
			'Crystalheart',
			'Energy',
			'Ghost',
			'Ingredient',
			'Metal',
			'Plant',
			'Seed',
			'Shadow Coin',
			'Soul',
			'Soulvine',
			'Star',
			'Tearbloom'
		},
		Darker = true
	})
end)

run(function()
	local CropESP
	local Color
	local Transparency
	local Scale
	local Reference = {}
	local Folder = Instance.new('Folder')
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	Folder.Parent = vape.gui
	
	local function Added(ent)
		local nametag = Instance.new('TextLabel')
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		nametag.Text = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or 'Crop'
		local size = getfontbounds(nametag.Text, nametag.TextSize, nametag.FontFace)
		nametag.Name = ent.Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Transparency.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end
	
	CropESP = vape.Categories.Render:CreateModule({
		Name = 'CropESP',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('HarvestableCrop') do
					Added(v)
				end
				CropESP:Clean(collectionService:GetInstanceAddedSignal('HarvestableCrop'):Connect(Added))
				CropESP:Clean(collectionService:GetInstanceRemovedSignal('HarvestableCrop'):Connect(function(ent)
					if Reference[ent] then
						Reference[ent]:Destroy()
						Reference[ent] = nil
					end
				end))
				CropESP:Clean(runService.PreRender:Connect(function()
					for i, v in Reference do
						if not i.Parent then
							v:Destroy()
							Reference[i] = nil
							continue
						end
	
						local screenPos, visible = gameCamera:WorldToViewportPoint((i:IsA('Model') and i:GetPivot().Position or i.Position) + Vector3.new(0, 1, 0))
						v.Visible = visible
						if visible then
							v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
						end
					end
				end))
			else
				for i, v in Reference do
					v:Destroy()
					Reference[i] = nil
				end
			end
		end,
		Tooltip = 'Renders crops that are ready to harvest'
	})
	
	Color = CropESP:CreateColorSlider({
		Name = 'Text Color',
		Function = function()
			if not CropESP.Enabled then return end
			for _, v in Reference do
				v.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end
		end
	})
	Transparency = CropESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(value)
			if not CropESP.Enabled then return end
			for _, v in Reference do
				v.BackgroundTransparency = value
			end
		end,
		Default = 0.5
	})
	Scale = CropESP:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = function(value)
			if not CropESP.Enabled then return end
			for _, v in Reference do
				v.TextSize = 14 * value
				local size = getfontbounds(v.Text, v.TextSize, v.FontFace)
				v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			end
		end,
		Default = 1
	})
end)

run(function()
	local FPSBooster
	local Cosmetics
	local Animations
	local Clouds
	local Quality
	local Shadows
	local Post
	local Water
	local Kill
	local Visualizer
	local Particles
	local Nametags
	local Compatibility
	local hidden = {}
	local watching = setmetatable({}, {__mode = 'k'})
	local effects = {}
	local killeffects, visualizers, particlesold = {}, {}, {}
	local waterold
	local qualityold
	local shadowsold
	local technologyold
	local nametagold
	local posthook
	local particlehook
	local particleclasses = {'ParticleEmitter', 'Trail', 'Beam', 'Smoke', 'Fire', 'Sparkles'}
	
	local function silenceParticle(obj)
		if not table.find(particleclasses, obj.ClassName) or particlesold[obj] ~= nil then return end
		particlesold[obj] = obj.Enabled
		obj.Enabled = false
	end
	
	local function stripEffect(effect)
		if effects[effect] ~= nil then return end
		for _, v in vape.BlurEffects or {} do
			if v == effect then return end
		end
	
		if effect:IsA('PostEffect') then
			effects[effect] = effect.Enabled
			effect.Enabled = false
		elseif effect:IsA('Atmosphere') then
			effects[effect] = effect.Density
			effect.Density = 0
		end
	end
	
	local function setSpeed(speed)
		for _, v in entitylib.List do
			if v.Player ~= lplr then
				local humanoid = v.Character:FindFirstChildWhichIsA('Humanoid')
				local animator = humanoid and humanoid:FindFirstChildWhichIsA('Animator')
				for _, v2 in animator and animator:GetPlayingAnimationTracks() or {} do
					v2:AdjustSpeed(speed)
				end
			end
		end
	end
	
	local function Added(ent)
		if not Cosmetics.Enabled or ent.Player == lplr then return end
	
		for _, v in ent.Character:GetChildren() do
			if v.Name == 'Clothing' or v.Name == '3DClothing' then
				hidden[v] = v.Parent
				v.Parent = nil
			end
		end
	
		if not watching[ent.Character] then
			watching[ent.Character] = ent.Character.ChildAdded:Connect(function(obj)
				if FPSBooster.Enabled and Cosmetics.Enabled and (obj.Name == 'Clothing' or obj.Name == '3DClothing') then
					task.defer(function()
						if FPSBooster.Enabled and Cosmetics.Enabled and obj.Parent == ent.Character then
							hidden[obj] = ent.Character
							obj.Parent = nil
						end
					end)
				end
			end)
		end
	end
	
	local function Removed(ent)
		if watching[ent.Character] then
			watching[ent.Character]:Disconnect()
			watching[ent.Character] = nil
		end
	
		for i, v in hidden do
			if v == ent.Character then
				hidden[i] = nil
			end
		end
	end
	
	FPSBooster = vape.Categories.Render:CreateModule({
		Name = 'FPSBooster',
		Function = function(callback)
			if callback then
				if Quality.Enabled then
					pcall(function()
						qualityold = settings().Rendering.QualityLevel
						settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
					end)
				end
	
				if Shadows.Enabled then
					shadowsold = lightingService.GlobalShadows
					lightingService.GlobalShadows = false
				end
	
				if Post.Enabled then
					for _, v in lightingService:GetChildren() do
						stripEffect(v)
					end
	
					posthook = lightingService.ChildAdded:Connect(function(v)
						if FPSBooster.Enabled and Post.Enabled then
							task.defer(stripEffect, v)
						end
					end)
				end
	
				if Water.Enabled then
					waterold = {
						Size = workspace.Terrain.WaterWaveSize,
						Speed = workspace.Terrain.WaterWaveSpeed,
						Reflectance = workspace.Terrain.WaterReflectance,
						Transparency = workspace.Terrain.WaterTransparency
					}
					workspace.Terrain.WaterWaveSize = 0
					workspace.Terrain.WaterWaveSpeed = 0
					workspace.Terrain.WaterReflectance = 0
					workspace.Terrain.WaterTransparency = 1
				end
	
				if Compatibility.Enabled then
					technologyold = lightingService.Technology
					lightingService.Technology = Enum.Technology.Compatibility
				end
	
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							killeffects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function()
									return {
										onKill = function() end,
										isPlayDefaultKillEffect = function()
											return true
										end
									}
								end
							}
						end
					end
				end
	
				if Visualizer.Enabled then
					for i, v in bedwars.VisualizerUtils do
						visualizers[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
	
				if Particles.Enabled then
					particlehook = workspace.DescendantAdded:Connect(silenceParticle)
					task.spawn(function()
						local clock = os.clock()
						for _, v in workspace:GetDescendants() do
							silenceParticle(v)
	
							if os.clock() - clock > 0.002 then
								task.wait()
								if not FPSBooster.Enabled or not Particles.Enabled then return end
								clock = os.clock()
							end
						end
					end)
				end
	
				if Nametags.Enabled then
					task.spawn(function()
						repeat task.wait() until store.matchState ~= 0 or not FPSBooster.Enabled
						if not FPSBooster.Enabled or not Nametags.Enabled or not bedwars.AppController then return end
	
						nametagold = bedwars.NametagController.addGameNametag
						bedwars.NametagController.addGameNametag = function() end
						for _, v in bedwars.AppController:getOpenApps() do
							if tostring(v):find('Nametag') then
								bedwars.AppController:closeApp(tostring(v))
							end
						end
					end)
				end
	
				if Clouds.Enabled then
					local clouds = workspace:FindFirstChild('Clouds')
					if clouds then
						hidden[clouds] = clouds.Parent
						clouds.Parent = nil
					end
				end
	
				if Cosmetics.Enabled then
					FPSBooster:Clean(entitylib.Events.EntityAdded:Connect(Added))
					FPSBooster:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
					for _, v in entitylib.List do
						Added(v)
					end
				end
	
				if Animations.Enabled then
					task.spawn(function()
						repeat
							setSpeed(0)
							task.wait(0.5)
						until not FPSBooster.Enabled or not Animations.Enabled
					end)
				end
			else
				if posthook then
					posthook:Disconnect()
					posthook = nil
				end
	
				if particlehook then
					particlehook:Disconnect()
					particlehook = nil
				end
	
				for i, v in effects do
					if i.Parent then
						if i:IsA('Atmosphere') then
							i.Density = v
						else
							i.Enabled = v
						end
					end
				end
				table.clear(effects)
	
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects[i] = v
				end
				table.clear(killeffects)
	
				for i, v in visualizers do
					bedwars.VisualizerUtils[i] = v
				end
				table.clear(visualizers)
	
				for i, v in particlesold do
					if i.Parent then
						i.Enabled = v
					end
				end
				table.clear(particlesold)
	
				if nametagold then
					bedwars.NametagController.addGameNametag = nametagold
					nametagold = nil
				end
	
				if technologyold then
					lightingService.Technology = technologyold
					technologyold = nil
				end
	
				if waterold then
					workspace.Terrain.WaterWaveSize = waterold.Size
					workspace.Terrain.WaterWaveSpeed = waterold.Speed
					workspace.Terrain.WaterReflectance = waterold.Reflectance
					workspace.Terrain.WaterTransparency = waterold.Transparency
					waterold = nil
				end
	
				for _, v in watching do
					v:Disconnect()
				end
				table.clear(watching)
	
				for i, v in hidden do
					if v.Parent then
						i.Parent = v
					end
				end
	
				table.clear(hidden)
				setSpeed(1)
	
				if qualityold then
					pcall(function()
						settings().Rendering.QualityLevel = qualityold
					end)
					qualityold = nil
				end
	
				if shadowsold ~= nil then
					lightingService.GlobalShadows = shadowsold
					shadowsold = nil
				end
			end
		end,
		Tooltip = 'Strips the parts of the scene that actually cost frames'
	})
	
	Cosmetics = FPSBooster:CreateToggle({
		Name = 'Cosmetics',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides everyone else\'s skins, the biggest win of the four.\nBodies and held items stay visible'
	})
	Animations = FPSBooster:CreateToggle({
		Name = 'Freeze animations',
		Function = function(callback)
			if FPSBooster.Enabled and not callback then
				setSpeed(1)
			end
	
			if FPSBooster.Enabled and callback then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Tooltip = 'Stops everyone else animating, they slide around instead.\nUnverified on your machine, A/B it yourself'
	})
	Clouds = FPSBooster:CreateToggle({
		Name = 'Clouds',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Removes the cloud decoration, around 700 parts on most maps'
	})
	Quality = FPSBooster:CreateToggle({
		Name = 'Render quality',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Drops the engine render quality to its lowest level'
	})
	Shadows = FPSBooster:CreateToggle({
		Name = 'Shadows',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Turns off global shadows'
	})
	Post = FPSBooster:CreateToggle({
		Name = 'Post effects',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Turns off sun rays, depth of field and colour correction, whole render passes the card does every frame.\nThe GUI blur is left alone'
	})
	Water = FPSBooster:CreateToggle({
		Name = 'Water',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Flattens terrain water, no waves and no reflection.\nOnly does anything on maps that have water'
	})
	Compatibility = FPSBooster:CreateToggle({
		Name = 'Compatibility lighting',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Drops the map to compatibility lighting, the cheapest renderer Roblox has'
	})
	Kill = FPSBooster:CreateToggle({
		Name = 'Kill effects',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Stops other peoples kill effects from playing'
	})
	Visualizer = FPSBooster:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Turns off the games own visual effect helpers'
	})
	Particles = FPSBooster:CreateToggle({
		Name = 'Particles',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Stops every particle, trail and beam in the map from rendering'
	})
	Nametags = FPSBooster:CreateToggle({
		Name = 'Nametags',
		Function = function()
			if FPSBooster.Enabled then
				FPSBooster:Toggle()
				FPSBooster:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Hides the game nametags once the match starts'
	})
end)

run(function()
	local GeneratorESP
	local Transparency
	local Scale
	local Whitelist
	local Whitelisted = {}
	local Reference, Cooldown = {}, {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		local app = ent:FindFirstChild('RoactTree')
		app = app and app:FindFirstChild('TeamOreGeneratorApp')
		if not app then return end
	
		local title = app:FindFirstChild('Title', true)
		local name, tier = title and title.Text, 'iron'
		if not name then
			local ore = ent:GetAttribute('Id')
			if not ore then return end
			ore = ore:sub(1, #ore - 2)
			tier = ore:lower()
			name = `{ore:sub(1, 1):upper()}{ore:sub(2)} Generator`
		end
	
		if Whitelist.Enabled and not table.find(Whitelisted.ListEnabled, tier) then return end
	
		local nametag = Instance.new('TextLabel')
		nametag.Name = name
		nametag.Text = `{name} | T{ent:GetAttribute('GeneratorLevel') or 0}`
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local size = getfontbounds(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace)
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Transparency.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.TextColor3 = Color3.new(1, 1, 1)
		nametag.RichText = true
		nametag.Parent = Folder
		Cooldown[ent] = app:FindFirstChild('Countdown', true) or app:FindFirstChild('Timer', true)
		Reference[ent] = nametag
	end
	
	GeneratorESP = vape.Categories.Render:CreateModule({
		Name = 'GeneratorESP',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('Generator') do
					Added(v)
				end
				GeneratorESP:Clean(collectionService:GetInstanceAddedSignal('Generator'):Connect(Added))
				GeneratorESP:Clean(collectionService:GetInstanceRemovedSignal('Generator'):Connect(function(ent)
					if Reference[ent] then
						Reference[ent]:Destroy()
						Reference[ent] = nil
						Cooldown[ent] = nil
					end
				end))
				GeneratorESP:Clean(runService.PreRender:Connect(function()
					for i, v in Reference do
						if not i.Parent then
							v:Destroy()
							Reference[i] = nil
							Cooldown[i] = nil
							continue
						end
	
						local screenPos, visible = gameCamera:WorldToViewportPoint(i.Position + Vector3.new(0, 1, 0))
						v.Visible = visible
						if not visible then continue end
	
						local timer = Cooldown[i]
						timer = timer and timer.Parent and (timer.Text:match('%[([%d%.]+)%]') or timer.Text:match('([%d%.]+)'))
						local text = `{v.Name} | T{i:GetAttribute('GeneratorLevel') or 0}{timer and ` | {timer}s` or ''}`
						if v.Text ~= text then
							v.Text = text
							local size = getfontbounds(removeTags(text), v.TextSize, v.FontFace)
							v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						end
						v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
					end
				end))
			else
				for i, v in Reference do
					v:Destroy()
					Reference[i] = nil
					Cooldown[i] = nil
				end
			end
		end,
		Tooltip = 'Renders generator locations and info'
	})
	
	Transparency = GeneratorESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(value)
			if not GeneratorESP.Enabled then return end
			for _, v in Reference do
				v.BackgroundTransparency = value
			end
		end,
		Default = 0.5
	})
	Scale = GeneratorESP:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = function(value)
			if not GeneratorESP.Enabled then return end
			for _, v in Reference do
				v.TextSize = 14 * value
				local size = getfontbounds(removeTags(v.Text), v.TextSize, v.FontFace)
				v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			end
		end,
		Default = 1
	})
	Whitelist = GeneratorESP:CreateToggle({
		Name = 'Use whitelist',
		Function = function(callback)
			if Whitelisted.Object then
				Whitelisted.Object.Visible = callback
			end
			if GeneratorESP.Enabled then
				GeneratorESP:Toggle()
				GeneratorESP:Toggle()
			end
		end,
		Default = true
	})
	Whitelisted = GeneratorESP:CreateTextList({
		Name = 'Generators',
		Function = function()
			if GeneratorESP.Enabled then
				GeneratorESP:Toggle()
				GeneratorESP:Toggle()
			end
		end,
		Default = {'diamond', 'iron'},
		Darker = true
	})
end)

run(function()
	local ESPSplitModule
	local SplitRadius
	local UpdateRate
	local DebugLog
	local AutoUpdate

	local espsplit = {
		Cache = {},
		Generators = {},
		LastUpdate = 0,
		Enabled = false
	}

	local function getGenPosition(ent)
		if not ent then return nil end
		if ent:IsA('BasePart') then
			return ent.Position
		elseif ent:IsA('Model') then
			if ent.PrimaryPart then
				return ent.PrimaryPart.Position
			end
			local pivot = ent:GetPivot()
			return pivot.Position
		end
		return nil
	end

	local function getGenInfo(ent)
		local pos = getGenPosition(ent)
		if not pos then return nil end

		local app = ent:FindFirstChild('RoactTree') and ent.RoactTree:FindFirstChild('TeamOreGeneratorApp')
		local titleObj = app and (app:FindFirstChild('GlobalOreGenerator') or app:FindFirstChild('TeamGenMain'))
		if titleObj then
			titleObj = titleObj:FindFirstChild('Title')
		end

		local name = ''
		local genType = 'team'
		local team = ent:GetAttribute('Team')

		if titleObj and titleObj.Text and #titleObj.Text > 0 then
			name = titleObj.Text
			local lowerName = name:lower()
			if lowerName:find('diamond') then
				genType = 'diamond'
			elseif lowerName:find('emerald') then
				genType = 'emerald'
			else
				genType = 'team'
			end
		else
			local ore = ent:GetAttribute('Id')
			if ore then
				local rawOre = ore:sub(0, #ore - 2)
				genType = rawOre:lower()
				name = (rawOre:sub(1, 1):upper() .. rawOre:sub(2):lower()) .. ' Generator'
			else
				local entName = ent.Name
				if entName:lower():find('diamond') then
					genType = 'diamond'
					name = 'Diamond Generator'
				elseif entName:lower():find('emerald') then
					genType = 'emerald'
					name = 'Emerald Generator'
				else
					genType = 'team'
					name = team and (team .. ' Team Generator') or 'Team Generator'
				end
			end
		end

		local level = ent:GetAttribute('GeneratorLevel') or ent:GetAttribute('Tier') or 1
		local id = ent:GetAttribute('Id') or (name .. '_' .. tostring(math.floor(pos.X)) .. '_' .. tostring(math.floor(pos.Z)))

		return {
			instance = ent,
			id = id,
			name = name,
			type = genType,
			team = team,
			level = level,
			position = pos
		}
	end

	local function discoverGenerators()
		local detected = {}
		local checked = {}

		local function addGen(ent)
			if not ent or checked[ent] then return end
			checked[ent] = true
			local info = getGenInfo(ent)
			if info then
				table.insert(detected, info)
			end
		end

		for _, ent in collectionService:GetTagged('Generator') do
			addGen(ent)
		end

		for _, tag in {'diamond_OreGenerator', 'emerald_OreGenerator'} do
			for _, ent in collectionService:GetTagged(tag) do
				addGen(ent)
			end
		end

		local teamNames = {'Blue', 'Red', 'Green', 'Yellow', 'Orange', 'Cyan', 'Pink', 'Purple', 'White', 'Black'}
		for _, teamName in teamNames do
			for _, ent in collectionService:GetTagged(teamName .. '_TeamOreGenerator') do
				addGen(ent)
			end
		end

		local oreGensFolder = workspace:FindFirstChild('OreGenerators') or (workspace:FindFirstChild('Map') and workspace.Map:FindFirstChild('OreGenerators'))
		if oreGensFolder then
			for _, child in oreGensFolder:GetChildren() do
				addGen(child)
			end
		end

		espsplit.Generators = detected
		return detected
	end

	local function getItemDropPosition(drop)
		if not drop then return nil end
		if drop:IsA('BasePart') then
			return drop.Position
		elseif drop:IsA('Model') then
			if drop.PrimaryPart then
				return drop.PrimaryPart.Position
			end
			return drop:GetPivot().Position
		end
		return nil
	end

	local function getAllItemDrops()
		local drops = {}
		local itemDropsFolder = workspace:FindFirstChild('ItemDrops')
		if itemDropsFolder then
			for _, drop in itemDropsFolder:GetChildren() do
				table.insert(drops, drop)
			end
		else
			for _, drop in collectionService:GetTagged('ItemDrop') do
				table.insert(drops, drop)
			end
		end
		return drops
	end

	local function analyzeAll(customRadius)
		local radius = customRadius or (SplitRadius and SplitRadius.Value) or 15
		local generators = #espsplit.Generators > 0 and espsplit.Generators or discoverGenerators()
		local drops = getAllItemDrops()

		local results = {}
		for _, gen in generators do
			results[gen.instance] = {
				instance = gen.instance,
				id = gen.id,
				name = gen.name,
				type = gen.type,
				team = gen.team,
				level = gen.level,
				position = gen.position,
				total = 0,
				resources = {
					iron = 0,
					gold = 0,
					diamond = 0,
					emerald = 0
				},
				items = {}
			}
		end

		for _, drop in drops do
			local dropPos = getItemDropPosition(drop)
			if not dropPos then continue end
			local closestGen = nil
			local closestDist = radius

			for _, gen in generators do
				local genPos = gen.position
				local xzDist = math.sqrt((dropPos.X - genPos.X)^2 + (dropPos.Z - genPos.Z)^2)
				local yDist = math.abs(dropPos.Y - genPos.Y)

				if xzDist <= radius and yDist <= 14 then
					if xzDist < closestDist then
						closestDist = xzDist
						closestGen = gen
					end
				end
			end

			if closestGen and results[closestGen.instance] then
				local genData = results[closestGen.instance]
				local rawName = drop.Name:lower()
				local amount = tonumber(drop:GetAttribute('Amount')) or 1

				genData.resources[rawName] = (genData.resources[rawName] or 0) + amount
				genData.total = genData.total + amount
				table.insert(genData.items, {
					instance = drop,
					name = rawName,
					amount = amount,
					position = dropPos
				})
			end
		end

		local list = {}
		for _, data in results do
			table.insert(list, data)
		end

		table.sort(list, function(a, b)
			if a.type == b.type then
				return a.name < b.name
			end
			local order = {emerald = 1, diamond = 2, team = 3}
			return (order[a.type] or 4) < (order[b.type] or 4)
		end)

		espsplit.Cache = list
		espsplit.LastUpdate = tick()
		if vapeEvents and vapeEvents.SplitUpdate then
			vapeEvents.SplitUpdate:Fire(list)
		end

		return list
	end

	local function analyzeGenerator(genInstanceOrId, customRadius)
		local radius = customRadius or (SplitRadius and SplitRadius.Value) or 15
		local genInfo = nil

		if typeof(genInstanceOrId) == 'Instance' then
			genInfo = getGenInfo(genInstanceOrId)
		else
			for _, g in espsplit.Generators do
				if g.id == genInstanceOrId or g.name == genInstanceOrId then
					genInfo = g
					break
				end
			end
		end

		if not genInfo then return nil end

		local genPos = genInfo.position
		local drops = getAllItemDrops()

		local result = {
			instance = genInfo.instance,
			id = genInfo.id,
			name = genInfo.name,
			type = genInfo.type,
			team = genInfo.team,
			level = genInfo.level,
			position = genPos,
			total = 0,
			resources = {
				iron = 0,
				gold = 0,
				diamond = 0,
				emerald = 0
			},
			items = {}
		}

		for _, drop in drops do
			local dropPos = getItemDropPosition(drop)
			if not dropPos then continue end
			local xzDist = math.sqrt((dropPos.X - genPos.X)^2 + (dropPos.Z - genPos.Z)^2)
			local yDist = math.abs(dropPos.Y - genPos.Y)

			if xzDist <= radius and yDist <= 14 then
				local rawName = drop.Name:lower()
				local amount = tonumber(drop:GetAttribute('Amount')) or 1

				result.resources[rawName] = (result.resources[rawName] or 0) + amount
				result.total = result.total + amount
				table.insert(result.items, {
					instance = drop,
					name = rawName,
					amount = amount,
					position = dropPos
				})
			end
		end

		return result
	end

	local function formatSplit(genData)
		if not genData then return 'N/A' end
		local parts = {}
		if (genData.resources.emerald or 0) > 0 then
			table.insert(parts, `🟢 x{genData.resources.emerald}`)
		end
		if (genData.resources.diamond or 0) > 0 then
			table.insert(parts, `💎 x{genData.resources.diamond}`)
		end
		if (genData.resources.gold or 0) > 0 then
			table.insert(parts, `🟡 x{genData.resources.gold}`)
		end
		if (genData.resources.iron or 0) > 0 then
			table.insert(parts, `⚪ x{genData.resources.iron}`)
		end
		for resName, resCount in genData.resources do
			if not table.find({'emerald', 'diamond', 'gold', 'iron'}, resName) and resCount > 0 then
				table.insert(parts, `{resName}: {resCount}`)
			end
		end

		local content = #parts > 0 and table.concat(parts, ' | ') or 'Empty (0)'
		return `{genData.name} [T{genData.level}]: {content}`
	end

	local function getSummary()
		local list = #espsplit.Cache > 0 and espsplit.Cache or analyzeAll()
		local summary = {
			totalGenerators = #list,
			totalEmeralds = 0,
			totalDiamonds = 0,
			totalIron = 0,
			totalGold = 0,
			generators = {}
		}

		for _, g in list do
			summary.totalEmeralds = summary.totalEmeralds + (g.resources.emerald or 0)
			summary.totalDiamonds = summary.totalDiamonds + (g.resources.diamond or 0)
			summary.totalIron = summary.totalIron + (g.resources.iron or 0)
			summary.totalGold = summary.totalGold + (g.resources.gold or 0)
			table.insert(summary.generators, {
				name = g.name,
				type = g.type,
				total = g.total,
				formatted = formatSplit(g)
			})
		end
		return summary
	end

	local function printAnalysis()
		local list = analyzeAll()
		print('========================================')
		print(`[ESPSplit] Resource Analysis ({#list} Generators Detected)`)
		print('========================================')
		for i, g in list do
			print(`#{i} ` .. formatSplit(g))
		end
		print('========================================')
		if notif then
			notif('ESPSplit', `Analyzed {#list} generators. Check console (F9)!`, 5, 'info')
		end
	end

	local function getNearestGenerator(pos)
		local generators = #espsplit.Generators > 0 and espsplit.Generators or discoverGenerators()
		local nearest, nearestDist = nil, math.huge
		for _, gen in generators do
			local dist = (gen.position - pos).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = gen
			end
		end
		return nearest, nearestDist
	end

	espsplit.discoverGenerators = discoverGenerators
	espsplit.getGenerators = function()
		return #espsplit.Generators > 0 and espsplit.Generators or discoverGenerators()
	end
	espsplit.getAllItemDrops = getAllItemDrops
	espsplit.analyzeAll = analyzeAll
	espsplit.analyzeGenerator = analyzeGenerator
	espsplit.formatSplit = formatSplit
	espsplit.getSummary = getSummary
	espsplit.printAnalysis = printAnalysis
	espsplit.getNearestGenerator = getNearestGenerator

	setmetatable(espsplit, {
		__call = function(_, radius)
			return analyzeAll(radius)
		end
	})

	getgenv().espsplit = espsplit
	getgenv().ESPSplit = espsplit
	bedwars.espsplit = espsplit
	bedwars.ESPSplit = espsplit

	local Folder = Instance.new('Folder')
	Folder.Name = 'ESPSplitFolder'
	Folder.Parent = vape.gui

	local VisualReference = {}
	local Background
	local Color = {}
	local Diamonds
	local Emeralds
	local TeamBases
	local EnemyBasesOnly
	local ShowNames
	local Distance
	local ShowTier
	local ShowTotal
	local HideEmpty
	local Scale
	local IconSize
	local SplitRadius
	local MaxDistance
	local UpdateRate
	local AutoUpdate
	local DebugLog

	local function getLocalTeam()
		if lplr then
			local teamAttr = lplr:GetAttribute('Team')
			if teamAttr then return tostring(teamAttr) end
			if lplr.Team then return tostring(lplr.Team.Name) end
		end
		if bedwars and bedwars.Store then
			local s = bedwars.Store:getState()
			if s and s.Game and s.Game.myTeam then
				return tostring(s.Game.myTeam.id or s.Game.myTeam.name or '')
			end
		end
		return nil
	end

	local function getBadgeIcon(resName)
		if bedwars and bedwars.getIcon then
			local icon = bedwars.getIcon({itemType = resName}, true)
			if icon and icon ~= '' then
				return icon
			end
		end
		local icons = {
			diamond = 'rbxassetid://6977794356',
			emerald = 'rbxassetid://6977794017',
			iron = 'rbxassetid://6977794770',
			gold = 'rbxassetid://6977794576'
		}
		return icons[resName] or ''
	end

	local function getResColor(resName)
		if resName == 'diamond' then
			return Color3.fromRGB(110, 230, 255)
		elseif resName == 'emerald' then
			return Color3.fromRGB(90, 255, 130)
		elseif resName == 'gold' then
			return Color3.fromRGB(255, 215, 80)
		elseif resName == 'iron' then
			return Color3.fromRGB(225, 230, 240)
		end
		return Color3.fromRGB(240, 240, 240)
	end

	local function createBillboard(gen)
		local adornee = gen.instance:IsA('BasePart') and gen.instance or (gen.instance:IsA('Model') and (gen.instance.PrimaryPart or gen.instance:FindFirstChildWhichIsA('BasePart')))
		if not adornee then return nil end

		local bbg = Instance.new('BillboardGui')
		bbg.Name = 'ESPSplit_' .. tostring(gen.id)
		bbg.Adornee = adornee
		bbg.AlwaysOnTop = true
		bbg.ClipsDescendants = false
		bbg.LightInfluence = 0
		bbg.ResetOnSpawn = false
		bbg.Size = UDim2.fromOffset(28, 16)
		bbg.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		bbg.Parent = Folder

		local blur = addBlur(bbg)
		blur.Visible = Background and Background.Enabled or true

		local frame = Instance.new('Frame')
		frame.Name = 'PlateFrame'
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color.Hue and Color3.fromHSV(Color.Hue, Color.Sat, Color.Value) or Color3.fromRGB(20, 20, 25)
		frame.BackgroundTransparency = 1 - ((Background and Background.Enabled) and (Color.Opacity or 0.65) or 0)
		frame.BorderSizePixel = 0
		frame.Parent = bbg

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame

		local stroke = Instance.new('UIStroke')
		stroke.Name = 'Stroke'
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.88
		stroke.Thickness = 1
		stroke.Parent = frame

		local padding = Instance.new('UIPadding')
		padding.PaddingTop = UDim.new(0, 2)
		padding.PaddingBottom = UDim.new(0, 2)
		padding.PaddingLeft = UDim.new(0, 3)
		padding.PaddingRight = UDim.new(0, 3)
		padding.Parent = frame

		local vLayout = Instance.new('UIListLayout')
		vLayout.Name = 'MainLayout'
		vLayout.FillDirection = Enum.FillDirection.Vertical
		vLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		vLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		vLayout.Padding = UDim.new(0, 2)
		vLayout.Parent = frame

		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.BackgroundTransparency = 1
		title.Text = ''
		title.RichText = true
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Font = Enum.Font.GothamBold
		title.TextSize = 10
		title.TextStrokeTransparency = 0.4
		title.Size = UDim2.fromOffset(0, 11)
		title.AutomaticSize = Enum.AutomaticSize.X
		title.Visible = false
		title.Parent = frame

		local resContainer = Instance.new('Frame')
		resContainer.Name = 'Resources'
		resContainer.BackgroundTransparency = 1
		resContainer.Size = UDim2.fromOffset(0, 16)
		resContainer.AutomaticSize = Enum.AutomaticSize.X
		resContainer.Parent = frame

		local hLayout = Instance.new('UIListLayout')
		hLayout.Name = 'ResLayout'
		hLayout.FillDirection = Enum.FillDirection.Horizontal
		hLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		hLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		hLayout.Padding = UDim.new(0, 3)
		hLayout.Parent = resContainer

		local function adjustSize()
			local scaleVal = (Scale and Scale.Value or 0.7)
			local contentX = math.max(title.Visible and title.AbsoluteSize.X or 0, resContainer.AbsoluteSize.X)
			local contentY = (title.Visible and (title.AbsoluteSize.Y + math.round(2 * scaleVal)) or 0) + resContainer.AbsoluteSize.Y
			local padX = math.round(8 * scaleVal)
			local padY = math.round(4 * scaleVal)
			bbg.Size = UDim2.fromOffset(math.max(contentX + padX, math.round(20 * scaleVal)), math.max(contentY + padY, math.round(14 * scaleVal)))
		end

		title:GetPropertyChangedSignal('AbsoluteSize'):Connect(adjustSize)
		resContainer:GetPropertyChangedSignal('AbsoluteSize'):Connect(adjustSize)

		VisualReference[gen.instance] = bbg
		return bbg
	end

	local function updateBillboard(gen, data)
		local bbg = VisualReference[gen.instance]
		if not bbg or not bbg.Parent then
			bbg = createBillboard(gen)
		end
		if not bbg then return end

		local currentPos = (entitylib.isAlive and entitylib.character and entitylib.character.RootPart) and entitylib.character.RootPart.Position or (gameCamera and gameCamera.CFrame.Position) or Vector3.zero
		local dist = math.floor((currentPos - gen.position).Magnitude)

		if MaxDistance and dist > MaxDistance.Value then
			bbg.Enabled = false
			return
		end

		if Diamonds and not Diamonds.Enabled and (gen.type == 'diamond' or gen.name:lower():find('diamond')) then
			bbg.Enabled = false
			return
		end

		if Emeralds and not Emeralds.Enabled and (gen.type == 'emerald' or gen.name:lower():find('emerald')) then
			bbg.Enabled = false
			return
		end

		local isTeamGen = (gen.type == 'team' or gen.team ~= nil)
		if TeamBases and not TeamBases.Enabled and isTeamGen then
			bbg.Enabled = false
			return
		end

		if EnemyBasesOnly and EnemyBasesOnly.Enabled and isTeamGen then
			local myTeam = getLocalTeam()
			if myTeam and gen.team and tostring(gen.team):lower() == myTeam:lower() then
				bbg.Enabled = false
				return
			end
		end

		local totalRes = (data and data.total) or 0
		if HideEmpty and HideEmpty.Enabled and totalRes <= 0 then
			bbg.Enabled = false
			return
		end

		bbg.Enabled = true

		local scaleVal = (Scale and Scale.Value or 0.7)
		local baseIcon = (IconSize and IconSize.Value or 14)
		local iconPx = math.max(math.round(baseIcon * scaleVal), 8)
		local textSize = math.max(math.round(iconPx * 0.9), 8)
		local badgeHeight = iconPx + math.max(math.round(4 * scaleVal), 2)

		local plateFrame = bbg:FindFirstChild('PlateFrame')
		if not plateFrame then return end

		local title = plateFrame:FindFirstChild('Title')
		local resContainer = plateFrame:FindFirstChild('Resources')
		if not title or not resContainer then return end

		local pad = plateFrame:FindFirstChildWhichIsA('UIPadding')
		if pad then
			pad.PaddingTop = UDim.new(0, math.max(math.round(2 * scaleVal), 1))
			pad.PaddingBottom = UDim.new(0, math.max(math.round(2 * scaleVal), 1))
			pad.PaddingLeft = UDim.new(0, math.max(math.round(3 * scaleVal), 2))
			pad.PaddingRight = UDim.new(0, math.max(math.round(3 * scaleVal), 2))
		end

		local titleText = ''
		if Distance and Distance.Enabled then
			titleText = `<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">{dist}m</font><font color="rgb(85, 255, 85)">]</font>`
		end

		if ShowTier and ShowTier.Enabled and gen.level and gen.level > 0 then
			titleText = (titleText ~= '' and (titleText .. ' ') or '') .. `<font color="rgb(175, 175, 190)">[T{gen.level}]</font>`
		end

		if ShowNames and ShowNames.Enabled then
			local nameStr = ''
			if gen.type == 'diamond' then
				nameStr = '<font color="rgb(64, 224, 255)"><b>Diamond</b></font>'
			elseif gen.type == 'emerald' then
				nameStr = '<font color="rgb(85, 255, 85)"><b>Emerald</b></font>'
			elseif gen.team then
				nameStr = `<font color="rgb(255, 205, 80)"><b>{gen.team}</b></font>`
			else
				nameStr = `<b>{gen.name}</b>`
			end
			titleText = (titleText ~= '' and (titleText .. ' ' .. nameStr) or nameStr)
		end

		if ShowTotal and ShowTotal.Enabled and totalRes > 0 and (ShowNames and ShowNames.Enabled) then
			titleText = titleText .. ` <font color="rgb(235, 235, 240)">({totalRes})</font>`
		end

		if titleText == '' then
			title.Visible = false
			title.Text = ''
		else
			title.Visible = true
			title.Text = titleText
			title.TextSize = math.max(math.round(10 * scaleVal), 8)
		end

		resContainer.Size = UDim2.fromOffset(0, badgeHeight)

		for _, child in resContainer:GetChildren() do
			if child:IsA('Frame') or child:IsA('TextLabel') then
				child:Destroy()
			end
		end

		local hasAny = false
		local order = {'diamond', 'emerald', 'iron', 'gold'}
		if data and data.resources then
			for resName, _ in data.resources do
				if not table.find(order, resName) then
					table.insert(order, resName)
				end
			end

			for _, resName in order do
				local count = data.resources[resName] or 0
				if count > 0 then
					hasAny = true
					local badge = Instance.new('Frame')
					badge.Name = resName
					badge.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
					badge.BackgroundTransparency = (Background and Background.Enabled) and 0.45 or 0.8
					badge.Size = UDim2.fromOffset(0, badgeHeight)
					badge.AutomaticSize = Enum.AutomaticSize.X

					local badgeCorner = Instance.new('UICorner')
					badgeCorner.CornerRadius = UDim.new(0, math.max(math.round(3 * scaleVal), 2))
					badgeCorner.Parent = badge

					local badgePad = Instance.new('UIPadding')
					badgePad.PaddingLeft = UDim.new(0, math.max(math.round(3 * scaleVal), 1))
					badgePad.PaddingRight = UDim.new(0, math.max(math.round(4 * scaleVal), 2))
					badgePad.PaddingTop = UDim.new(0, math.max(math.round(1 * scaleVal), 0))
					badgePad.PaddingBottom = UDim.new(0, math.max(math.round(1 * scaleVal), 0))
					badgePad.Parent = badge

					local bLayout = Instance.new('UIListLayout')
					bLayout.FillDirection = Enum.FillDirection.Horizontal
					bLayout.VerticalAlignment = Enum.VerticalAlignment.Center
					bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
					bLayout.Padding = UDim.new(0, math.max(math.round(2 * scaleVal), 1))
					bLayout.Parent = badge

					local iconImg = Instance.new('ImageLabel')
					iconImg.Size = UDim2.fromOffset(iconPx, iconPx)
					iconImg.BackgroundTransparency = 1
					iconImg.Image = getBadgeIcon(resName)
					iconImg.Parent = badge

					local countLbl = Instance.new('TextLabel')
					countLbl.BackgroundTransparency = 1
					countLbl.Text = tostring(count)
					countLbl.TextColor3 = getResColor(resName)
					countLbl.TextSize = textSize
					countLbl.Font = Enum.Font.GothamBold
					countLbl.TextStrokeTransparency = 0.35
					countLbl.AutomaticSize = Enum.AutomaticSize.XY
					countLbl.Parent = badge

					badge.Parent = resContainer
				end
			end
		end

		if not hasAny then
			local emptyLbl = Instance.new('TextLabel')
			emptyLbl.Name = 'Empty'
			emptyLbl.BackgroundTransparency = 1
			emptyLbl.Text = '<font color="rgb(150, 150, 160)">0</font>'
			emptyLbl.RichText = true
			emptyLbl.TextSize = textSize
			emptyLbl.Font = Enum.Font.Gotham
			emptyLbl.AutomaticSize = Enum.AutomaticSize.XY
			emptyLbl.Parent = resContainer
		end

		local contentX = math.max(title.Visible and title.AbsoluteSize.X or 0, resContainer.AbsoluteSize.X)
		local contentY = (title.Visible and (title.AbsoluteSize.Y + math.round(2 * scaleVal)) or 0) + resContainer.AbsoluteSize.Y
		local padX = math.round(8 * scaleVal)
		local padY = math.round(4 * scaleVal)
		bbg.Size = UDim2.fromOffset(math.max(contentX + padX, math.round(20 * scaleVal)), math.max(contentY + padY, math.round(14 * scaleVal)))
	end

	local function clearAllVisuals()
		for _, v in VisualReference do
			if v and v.Parent then
				v:Destroy()
			end
		end
		table.clear(VisualReference)
		if Folder then
			Folder:ClearAllChildren()
		end
	end

	local function refreshVisuals()
		if not espsplit.Enabled then return end
		local gens = espsplit.getGenerators()
		local cacheMap = {}
		for _, data in espsplit.Cache do
			cacheMap[data.instance] = data
		end

		for _, gen in gens do
			local data = cacheMap[gen.instance]
			if not data then
				data = analyzeGenerator(gen.instance)
			end
			updateBillboard(gen, data)
		end
	end

	ESPSplitModule = vape.Categories.Render:CreateModule({
		Name = 'ESPSplit',
		Function = function(callback)
			espsplit.Enabled = callback
			if callback then
				discoverGenerators()
				for _, gen in espsplit.Generators do
					createBillboard(gen)
				end

				analyzeAll()
				refreshVisuals()

				ESPSplitModule:Clean(runService.Heartbeat:Connect(function()
					if AutoUpdate.Enabled and (tick() - espsplit.LastUpdate) >= (UpdateRate.Value or 0.5) then
						analyzeAll()
						refreshVisuals()
						if DebugLog.Enabled then
							print(`[ESPSplit] Updated {#espsplit.Cache} generators at {math.floor(tick())}`)
						end
					end
				end))

				local itemDropsFolder = workspace:FindFirstChild('ItemDrops')
				if itemDropsFolder then
					ESPSplitModule:Clean(itemDropsFolder.ChildAdded:Connect(function()
						task.wait(0.05)
						if espsplit.Enabled then
							analyzeAll()
							refreshVisuals()
						end
					end))
					ESPSplitModule:Clean(itemDropsFolder.ChildRemoved:Connect(function()
						task.wait(0.05)
						if espsplit.Enabled then
							analyzeAll()
							refreshVisuals()
						end
					end))
				end
			else
				clearAllVisuals()
				espsplit.Cache = {}
			end
		end,
		Tooltip = 'Displays sleek plates with resource counts and icons on all generators'
	})

	Diamonds = ESPSplitModule:CreateToggle({
		Name = 'Diamonds',
		Default = true,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Displays Diamond generators'
	})

	Emeralds = ESPSplitModule:CreateToggle({
		Name = 'Emeralds',
		Default = true,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Displays Emerald generators'
	})

	TeamBases = ESPSplitModule:CreateToggle({
		Name = 'Team Bases',
		Default = true,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Displays Team Base generators (Iron/Gold)'
	})

	EnemyBasesOnly = ESPSplitModule:CreateToggle({
		Name = 'Enemy Bases Only',
		Default = false,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Hides your own base generator and only shows enemy bases'
	})

	ShowNames = ESPSplitModule:CreateToggle({
		Name = 'Show Names',
		Default = false,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Shows generator text name (Blue Team, Diamond, etc.)'
	})

	Scale = ESPSplitModule:CreateSlider({
		Name = 'Scale',
		Min = 0.3,
		Max = 1.5,
		Default = 0.7,
		Decimal = 10,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Overall size scaling of plates and icons'
	})

	IconSize = ESPSplitModule:CreateSlider({
		Name = 'Icon Size',
		Min = 8,
		Max = 28,
		Default = 14,
		Decimal = 1,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Custom resource icon size in pixels'
	})

	Distance = ESPSplitModule:CreateToggle({
		Name = 'Distance',
		Default = false,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Shows distance tag [XXm] to generator'
	})

	ShowTier = ESPSplitModule:CreateToggle({
		Name = 'Show Tier',
		Default = false,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Shows generator tier tag [T1/T2/T3]'
	})

	HideEmpty = ESPSplitModule:CreateToggle({
		Name = 'Hide Empty',
		Default = false,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Hides plates for generators with 0 resources'
	})

	Background = ESPSplitModule:CreateToggle({
		Name = 'Background',
		Default = true,
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, bbg in VisualReference do
				if bbg and bbg:FindFirstChild('PlateFrame') then
					bbg.PlateFrame.BackgroundTransparency = 1 - (callback and (Color.Opacity or 0.65) or 0)
					if bbg:FindFirstChild('Blur') then
						bbg.Blur.Visible = callback
					end
				end
			end
		end,
		Tooltip = 'Renders background blur plate'
	})

	Color = ESPSplitModule:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.65,
		Function = function(hue, sat, val, opacity)
			for _, bbg in VisualReference do
				if bbg and bbg:FindFirstChild('PlateFrame') then
					bbg.PlateFrame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					bbg.PlateFrame.BackgroundTransparency = 1 - opacity
				end
			end
		end,
		Darker = true
	})

	SplitRadius = ESPSplitModule:CreateSlider({
		Name = 'Split Radius',
		Min = 5,
		Max = 30,
		Default = 15,
		Decimal = 1,
		Function = function()
			if espsplit.Enabled then
				analyzeAll()
				refreshVisuals()
			end
		end,
		Tooltip = 'Radius in studs to count resources as belonging to generator'
	})

	MaxDistance = ESPSplitModule:CreateSlider({
		Name = 'Max Distance',
		Min = 50,
		Max = 1000,
		Default = 400,
		Decimal = 1,
		Function = function()
			refreshVisuals()
		end,
		Tooltip = 'Max distance to render generator plates'
	})

	UpdateRate = ESPSplitModule:CreateSlider({
		Name = 'Update Rate',
		Min = 0.1,
		Max = 2,
		Default = 0.5,
		Decimal = 10,
		Tooltip = 'Analysis refresh rate in seconds'
	})

	AutoUpdate = ESPSplitModule:CreateToggle({
		Name = 'Auto Update',
		Default = true,
		Tooltip = 'Continuously recalculates resources in background'
	})

	DebugLog = ESPSplitModule:CreateToggle({
		Name = 'Debug Log',
		Default = false,
		Tooltip = 'Outputs updates to console'
	})
end)




run(function()
	local Headless
	local Hats
	
	local hidden = setmetatable({}, {__mode = 'k'})
	
	local function setHidden(character, hide)
		local head = character:FindFirstChild('Head')
		if not head then return end
	
		head.LocalTransparencyModifier = hide and 1 or 0
		for _, v in head:GetChildren() do
			if v:IsA('Decal') then
				if hide and not hidden[v] then
					hidden[v] = v.Transparency
				end
				v.Transparency = hide and 1 or (hidden[v] or 0)
			end
		end
	
		for _, v in character:GetChildren() do
			if v:IsA('Accessory') and v.Handle and v.Handle:FindFirstChild('HatAttachment') then
				v.Handle.LocalTransparencyModifier = hide and Hats.Enabled and 1 or 0
			end
		end
	end
	
	Headless = vape.Categories.Render:CreateModule({
		Name = 'Headless',
		Function = function(callback)
			if callback then
				Headless:Clean(runService.PreRender:Connect(function()
					if entitylib.isAlive then
						setHidden(lplr.Character, true)
					end
				end))
			elseif entitylib.isAlive then
				setHidden(lplr.Character, false)
			end
		end,
		Tooltip = 'Hides your own head'
	})
	
	Hats = Headless:CreateToggle({
		Name = 'Hide hats',
		Default = true,
		Tooltip = 'Hides anything worn on your head too'
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
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
					label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				end))
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)

run(function()
	local HitAccuracy
	local ShowColor
	local HideUnused
	local sources = {'ProjectileAura', 'ProjectileAimbot', 'SilentAim', 'TerraAimbot'}
	local rows = {}
	local holder
	
	local function addRow(name)
		local row = Instance.new('Frame')
		row.BackgroundTransparency = 1
		row.Name = name
		row.Size = UDim2.new(1, 0, 0, 20)
		row.Parent = holder
		local title = Instance.new('TextLabel')
		title.BackgroundTransparency = 1
		title.FontFace = uipallet.Font
		title.Position = UDim2.fromOffset(10, 0)
		title.Size = UDim2.new(1, -20, 1, 0)
		title.Text = name
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextSize = 14
		title.TextStrokeColor3 = Color3.new()
		title.TextStrokeTransparency = 0.8
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = row
		local value = title:Clone()
		value.Name = 'Value'
		value.Text = '--'
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.Parent = row
	
		rows[name] = {Object = row, Title = title, Value = value}
	end
	
	local function refresh()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local shown = 0
		for _, v in sources do
			local chance = store.hitchance[v]
			local live = chance and (tick() - chance.Clock) < 2
			local row = rows[v]
			row.Object.Visible = live or not HideUnused.Enabled
	
			if row.Object.Visible then
				row.Object.Position = UDim2.fromOffset(0, 6 + (shown * 20))
				row.Value.Text = live and `{math.round(chance.Value * 100)}%` or '--'
				row.Value.TextColor3 = (live and ShowColor.Enabled) and Color3.fromHSV(chance.Value * 0.33, 0.75, 1) or Color3.new(1, 1, 1)
				shown += 1
			end
		end
	
		rows.Waiting.Object.Visible = shown == 0
		holder.Size = UDim2.fromOffset(190, 12 + (math.max(shown, 1) * 20))
	end
	
	HitAccuracy = vape:CreateOverlay({
		Name = 'Hit Accuracy',
		Icon = getvapeasset('catsix/assets/new/aim.png'),
		Size = UDim2.fromOffset(18, 12),
		Position = UDim2.fromOffset(11, 14),
		Function = function(callback)
			if callback then
				repeat
					refresh()
					task.wait(0.05)
				until not HitAccuracy.Button or not HitAccuracy.Button.Enabled
			end
		end
	})
	
	HitAccuracy:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			for _, v in rows do
				v.Title.FontFace = val
				v.Value.FontFace = val
			end
		end
	})
	HideUnused = HitAccuracy:CreateToggle({
		Name = 'Hide unused',
		Function = function()
			if holder then
				refresh()
			end
		end,
		Default = true,
		Tooltip = 'Leaves out a module until it is actually aiming at someone'
	})
	ShowColor = HitAccuracy:CreateToggle({
		Name = 'Color the number',
		Default = true,
		Tooltip = 'Red through green as the chance climbs'
	})
	HitAccuracy:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			if holder then
				holder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				holder.BackgroundTransparency = 1 - opacity
			end
		end
	})
	
	holder = Instance.new('Frame')
	holder.BackgroundColor3 = Color3.new()
	holder.BackgroundTransparency = 0.5
	holder.Size = UDim2.fromOffset(190, 32)
	holder.Parent = HitAccuracy.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = holder
	addBlur(holder)
	for _, v in sources do
		addRow(v)
	end
	addRow('Waiting')
	rows.Waiting.Object.Position = UDim2.fromOffset(0, 6)
	rows.Waiting.Title.Text = 'Hit chance'
	refresh()
	vape:Clean(HitAccuracy.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		local newside = HitAccuracy.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
		holder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
		holder.Position = UDim2.fromScale(newside and 1 or 0, 0)
	end))
end)

run(function()
	local InventoryESP
	local Armor
	local Empty
	local Color = {}
	local window, headshot, nametag, grid, armorholder, armordivider
	local slots, armorslots = {}, {}
	local SlotCount = 24
	local SlotSize = 32
	local SlotPadding = 4
	local Columns = 6
	local HeaderHeight = 46
	
	local function createSlot(parent)
		local slot = Instance.new('Frame')
		slot.Size = UDim2.fromOffset(SlotSize, SlotSize)
		slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		slot.BorderSizePixel = 0
		slot.Visible = false
		slot.Parent = parent
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = slot
		local stroke = Instance.new('UIStroke')
		stroke.Color = color.Light(uipallet.Main, 0.034)
		stroke.Parent = slot
		local icon = Instance.new('ImageLabel')
		icon.Name = 'Icon'
		icon.Size = UDim2.fromOffset(SlotSize - 8, SlotSize - 8)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Parent = slot
		local amount = Instance.new('TextLabel')
		amount.Name = 'Amount'
		amount.Size = UDim2.fromOffset(SlotSize - 4, 11)
		amount.Position = UDim2.fromOffset(0, SlotSize - 13)
		amount.BackgroundTransparency = 1
		amount.Text = ''
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.TextSize = 11
		amount.TextColor3 = uipallet.Text
		amount.TextStrokeColor3 = Color3.new()
		amount.TextStrokeTransparency = 0.4
		amount.FontFace = uipallet.Font
		amount.Parent = slot
		return slot
	end
	
	local function setSlot(slot, item, highlight)
		if not item or not item.itemType then
			slot.Visible = false
			return
		end
	
		slot.Visible = true
		slot.Icon.Image = bedwars.getIcon(item, true)
		slot.Amount.Text = (item.amount or 1) > 1 and tostring(item.amount) or ''
		slot.UIStroke.Color = highlight and Color3.fromHSV(Color.Hue, Color.Sat, Color.Value) or color.Light(uipallet.Main, 0.034)
	end
	
	local function refresh()
		local ent, highest = nil, tick()
		for i, v in targetinfo.Targets do
			if v < tick() then
				targetinfo.Targets[i] = nil
				continue
			end
			if v > highest then
				ent, highest = i, v
			end
		end
	
		local player = ent and ent.Player or nil
		local inventory = player and store.inventories[player] or nil
		if not ent or (not inventory and not Empty.Enabled) then
			window.Visible = false
			return
		end
	
		window.Visible = true
		nametag.Text = player and player.DisplayName or (ent.Character and ent.Character.Name) or ''
		headshot.Image = 'rbxthumb://type=AvatarHeadShot&id='..(player and player.UserId or 1)..'&w=420&h=420'
	
		inventory = inventory or {items = {}, armor = {}}
		local hand = inventory.hand
		local shown = 0
		for i, v in slots do
			local item = inventory.items[i]
			setSlot(v, item, item and hand and item.tool == hand.tool)
			if v.Visible then
				shown = i
			end
		end
	
		local rows = math.max(math.ceil(shown / Columns), 1)
		local gridheight = (rows * SlotSize) + ((rows - 1) * SlotPadding)
		grid.Size = UDim2.new(1, -28, 0, gridheight)
	
		local height = HeaderHeight + 10 + gridheight + 10
		if Armor.Enabled then
			armordivider.Visible = true
			armorholder.Visible = true
			armordivider.Position = UDim2.fromOffset(0, height - 1)
	
			for i = 1, 3 do
				setSlot(armorslots[i], inventory.armor[i + 3])
			end
			setSlot(armorslots[4], hand, true)
	
			armorholder.Position = UDim2.fromOffset(14, height + 9)
			height += SlotSize + 19
		else
			armordivider.Visible = false
			armorholder.Visible = false
		end
	
		window.Size = UDim2.fromOffset(240, height)
	end
	
	InventoryESP = vape.Categories.Render:CreateModule({
		Name = 'InventoryESP',
		Function = function(callback)
			if callback then
				if not window then
					window = Instance.new('Frame')
					window.Name = 'InventoryESP'
					window.Size = UDim2.fromOffset(240, HeaderHeight)
					window.Position = UDim2.fromOffset(12, 260)
					window.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					window.BackgroundTransparency = 1 - Color.Opacity
					window.Visible = false
					window.Parent = vape.gui.ScaledGui
					addBlur(window)
					local corner = Instance.new('UICorner')
					corner.CornerRadius = UDim.new(0, 5)
					corner.Parent = window
	
					headshot = Instance.new('ImageLabel')
					headshot.Name = 'Headshot'
					headshot.Size = UDim2.fromOffset(26, 26)
					headshot.Position = UDim2.fromOffset(14, 11)
					headshot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
					headshot.Image = ''
					headshot.Parent = window
					local headcorner = Instance.new('UICorner')
					headcorner.CornerRadius = UDim.new(0, 4)
					headcorner.Parent = headshot
	
					nametag = Instance.new('TextLabel')
					nametag.Name = 'Name'
					nametag.Size = UDim2.new(1, -60, 0, 26)
					nametag.Position = UDim2.fromOffset(48, 11)
					nametag.BackgroundTransparency = 1
					nametag.Text = ''
					nametag.TextXAlignment = Enum.TextXAlignment.Left
					nametag.TextSize = 13
					nametag.TextColor3 = uipallet.Text
					nametag.TextTruncate = Enum.TextTruncate.AtEnd
					nametag.FontFace = uipallet.Font
					nametag.Parent = window
	
					local divider = Instance.new('Frame')
					divider.Name = 'Divider'
					divider.Size = UDim2.new(1, 0, 0, 1)
					divider.Position = UDim2.fromOffset(0, HeaderHeight - 1)
					divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
					divider.BorderSizePixel = 0
					divider.Parent = window
	
					grid = Instance.new('Frame')
					grid.Name = 'Items'
					grid.Size = UDim2.new(1, -28, 0, 0)
					grid.Position = UDim2.fromOffset(14, HeaderHeight + 10)
					grid.BackgroundTransparency = 1
					grid.Parent = window
					local layout = Instance.new('UIGridLayout')
					layout.CellSize = UDim2.fromOffset(SlotSize, SlotSize)
					layout.CellPadding = UDim2.fromOffset(SlotPadding, SlotPadding)
					layout.SortOrder = Enum.SortOrder.LayoutOrder
					layout.Parent = grid
	
					for i = 1, SlotCount do
						local slot = createSlot(grid)
						slot.LayoutOrder = i
						slots[i] = slot
					end
	
					armordivider = Instance.new('Frame')
					armordivider.Name = 'ArmorDivider'
					armordivider.Size = UDim2.new(1, 0, 0, 1)
					armordivider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
					armordivider.BorderSizePixel = 0
					armordivider.Parent = window
	
					armorholder = Instance.new('Frame')
					armorholder.Name = 'Armor'
					armorholder.Size = UDim2.fromOffset(240, SlotSize)
					armorholder.BackgroundTransparency = 1
					armorholder.Parent = window
					local armorlayout = Instance.new('UIListLayout')
					armorlayout.FillDirection = Enum.FillDirection.Horizontal
					armorlayout.Padding = UDim.new(0, SlotPadding)
					armorlayout.Parent = armorholder
	
					for i = 1, 4 do
						local slot = createSlot(armorholder)
						slot.LayoutOrder = i
						armorslots[i] = slot
					end
				end
	
				repeat
					refresh()
					task.wait(0.1)
				until not InventoryESP.Enabled
	
				window.Visible = false
			elseif window then
				window.Visible = false
			end
		end,
		Tooltip = 'Shows the inventory of whoever you are currently targeting'
	})
	
	Armor = InventoryESP:CreateToggle({
		Name = 'Show armor',
		Function = function()
			if InventoryESP.Enabled then
				refresh()
			end
		end,
		Default = true
	})
	Empty = InventoryESP:CreateToggle({
		Name = 'Show without data',
		Tooltip = 'Keeps the panel up when the server has not shared their inventory yet'
	})
	Color = InventoryESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			if window then
				window.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				window.BackgroundTransparency = 1 - opacity
			end
		end
	})
end)

run(function()
	local ItemESP
	local Distance
	local Transparency
	local Scale
	local WhitelistOnly
	local Whitelist = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(ent)
		local name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
		if WhitelistOnly.Enabled and not table.find(Whitelist.ListEnabled, name:lower()) then return end
	
		local amount = ent:GetAttribute('Amount') or 1
		local nametag = Instance.new('TextLabel')
		nametag.Name = name
		nametag.Text = `{name}{amount >= 2 and ` x{amount}` or ''}`
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local size = getfontbounds(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace)
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Transparency.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.TextColor3 = Color3.new(1, 1, 1)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end
	
	ItemESP = vape.Categories.Render:CreateModule({
		Name = 'ItemESP',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('ItemDrop') do
					Added(v)
				end
				ItemESP:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(Added))
				ItemESP:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(ent)
					if Reference[ent] then
						Reference[ent]:Destroy()
						Reference[ent] = nil
					end
				end))
				ItemESP:Clean(runService.PreRender:Connect(function()
					for i, v in Reference do
						if not i.Parent then
							v:Destroy()
							Reference[i] = nil
							continue
						end
	
						local screenPos, visible = gameCamera:WorldToViewportPoint(i.Position + Vector3.new(0, 1, 0))
						v.Visible = visible and i.Position.Y > -200
						if not v.Visible then continue end
	
						local amount = i:GetAttribute('Amount') or 1
						local text = `{v.Name}{amount >= 2 and ` x{amount}` or ''}`
						if Distance.Enabled then
							local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - i.Position).Magnitude) or 0
							text = `<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">{mag}</font><font color="rgb(85, 255, 85)">]</font> {text}`
						end
	
						if v.Text ~= text then
							v.Text = text
							local size = getfontbounds(removeTags(text), v.TextSize, v.FontFace)
							v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
						end
						v.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
					end
				end))
			else
				for i, v in Reference do
					v:Destroy()
					Reference[i] = nil
				end
			end
		end,
		Tooltip = 'Renders tags dropped items'
	})
	
	Distance = ItemESP:CreateToggle({
		Name = 'Distance',
		Tooltip = 'Shows the distance of the item'
	})
	Transparency = ItemESP:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Function = function(value)
			if not ItemESP.Enabled then return end
			for _, v in Reference do
				v.BackgroundTransparency = value
			end
		end,
		Default = 0.5
	})
	Scale = ItemESP:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = function(value)
			if not ItemESP.Enabled then return end
			for _, v in Reference do
				v.TextSize = 14 * value
				local size = getfontbounds(removeTags(v.Text), v.TextSize, v.FontFace)
				v.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			end
		end,
		Default = 1
	})
	WhitelistOnly = ItemESP:CreateToggle({
		Name = 'Whitelist Only',
		Function = function(callback)
			if Whitelist.Object then
				Whitelist.Object.Visible = callback
			end
			if ItemESP.Enabled then
				ItemESP:Toggle()
				ItemESP:Toggle()
			end
		end,
		Tooltip = 'Only renders whitelisted items'
	})
	Whitelist = ItemESP:CreateTextList({
		Name = 'Allowed items',
		Function = function()
			if ItemESP.Enabled then
				ItemESP:Toggle()
				ItemESP:Toggle()
			end
		end,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local ItemPlates
	local Whitelist
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function scanSide(self, start, tab)
		for _, v in sides do
			for i = 1, 15 do
				local block = getPlacedBlock(start + (v * i))
				if not block or block == self then break end
				if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
					table.insert(tab, block.Name)
				end
			end
		end
	end
	
	local function refreshAdornee(billboard)
		local adornee = billboard.Adornee
		if not adornee or not adornee.Parent then
			billboard.Enabled = false
			return
		end
	
		for _, v in billboard.Frame:GetChildren() do
			if v:IsA('ImageLabel') then
				v:Destroy()
			end
		end
	
		local alreadygot = {}
		scanSide(adornee, adornee.Position, alreadygot)
		scanSide(adornee, adornee.Position + Vector3.new(0, 0, 3), alreadygot)
		table.sort(alreadygot, function(a, b)
			local first = bedwars.ItemMeta[a]
			local second = bedwars.ItemMeta[b]
			return (first and first.block and first.block.health or 0) > (second and second.block and second.block.health or 0)
		end)
		billboard.Enabled = #alreadygot > 0
	
		for _, v in alreadygot do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = v}, true)
			blockimage.Parent = billboard.Frame
		end
	end
	
	local function Added(part)
		if not table.find(Whitelist.ListEnabled, part.Name) or Reference[part] then return end
	
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[part] = billboard
		refreshAdornee(billboard)
	end
	
	ItemPlates = vape.Categories.Render:CreateModule({
		Name = 'ItemPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('block') do
					task.spawn(Added, v)
				end
				ItemPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(function(data)
					local pos = data.blockRef.blockPosition * 3
					for i, v in Reference do
						if (pos - i.Position).Magnitude <= 30 then
							refreshAdornee(v)
						end
					end
				end))
				ItemPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(data)
					local pos = data.blockRef.blockPosition * 3
					for i, v in Reference do
						if (pos - i.Position).Magnitude <= 30 then
							refreshAdornee(v)
						end
					end
				end))
				ItemPlates:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(Added))
				ItemPlates:Clean(collectionService:GetInstanceRemovedSignal('block'):Connect(function(part)
					if Reference[part] then
						Reference[part]:Destroy()
						Reference[part] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays surrounding blocks around the item.'
	})
	
	Whitelist = ItemPlates:CreateTextList({
		Name = 'Whitelist',
		Function = function()
			if ItemPlates.Enabled then
				ItemPlates:Toggle()
				ItemPlates:Toggle()
			end
		end,
		Default = {'beehive'}
	})
	Background = ItemPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then
				Color.Object.Visible = callback
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = ItemPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - (Background.Enabled and opacity or 0)
			end
		end,
		Darker = true
	})
end)

run(function()
	local KitDisplay
	
	local function renderKit(entry)
		task.wait(0.3)
		if not KitDisplay.Enabled or not entry.Parent then return end
		local name = entry:FindFirstChild('PlayerName', true)
		if not name then return end
	
		local player
		for _, v in playersService:GetPlayers() do
			local displayName = bedwars.StreamerModeController and bedwars.StreamerModeController:getDisplayName(v)
			if v.Name == name.Text or v.DisplayName == name.Text or v:GetAttribute('DisguiseDisplayName') == name.Text or displayName == name.Text then
				player = v
				break
			end
		end
		if not player then return end
	
		local frame = entry:FindFirstChild('1')
		local card = frame and frame:FindFirstChild('MatchDraftPlayerCard')
		if not card then return end
	
		local roact = card:FindFirstChild('KitImage')
		local image = bedwars.BedwarsKitMeta[player:GetAttribute('PlayingAsKits')] or bedwars.BedwarsKitMeta.none
		if not roact then
			roact = Instance.new('ImageLabel')
			roact.BackgroundTransparency = 1
			roact.AnchorPoint = Vector2.new(1, 0.5)
			roact.Position = UDim2.fromScale(1.05, 0)
			roact.Name = 'KitImage'
			roact.Size = UDim2.fromScale(1.5, 1.5)
			roact.ZIndex = 1
			roact.ImageTransparency = 0.4
			roact.SliceCenter = Rect.new(0, 0, 0, 0)
			roact.SliceScale = 1
			roact.ScaleType = Enum.ScaleType.Crop
			roact.Parent = card
			KitDisplay:Clean(roact)
	
			local ratio = Instance.new('UIAspectRatioConstraint')
			ratio.Name = '1'
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
			ratio.Parent = roact
		end
	
		roact.Image = image.renderImage
		roact.Position = UDim2.fromScale(1.05, 0)
		tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(1.05, 0.5)
		}):Play()
	
		local connection = player:GetAttributeChangedSignal('PlayingAsKits'):Connect(function()
			if not KitDisplay.Enabled or not roact.Parent then return end
			image = bedwars.BedwarsKitMeta[player:GetAttribute('PlayingAsKits')] or bedwars.BedwarsKitMeta.none
			roact.Image = image.renderImage
			roact.Position = UDim2.fromScale(1.05, 0)
			tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(1.05, 0.5)
			}):Play()
		end)
		KitDisplay:Clean(name:GetPropertyChangedSignal('Text'):Once(function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			renderKit(entry)
		end))
		KitDisplay:Clean(connection)
	end
	
	KitDisplay = vape.Categories.Render:CreateModule({
		Name = 'KitDisplay',
		Function = function(callback)
			if callback then
				local bodyContainer
				repeat
					local app = lplr.PlayerGui:FindFirstChild('MatchDraftApp')
					local background = app and app:FindFirstChild('DraftAppBackground')
					local frame = background and background:FindFirstChild('1')
					bodyContainer = frame and frame:FindFirstChild('BodyContainer')
					if not bodyContainer then task.wait(0.1) end
				until bodyContainer or not KitDisplay.Enabled
	
				for i = 1, 2 do
					if not KitDisplay.Enabled then break end
					local column
					local deadline = tick() + 10
					repeat
						column = bodyContainer:FindFirstChild(`Team{i}Column`)
						if not column then task.wait(0.1) end
					until column or not KitDisplay.Enabled or tick() >= deadline
	
					if column then
						KitDisplay:Clean(column.ChildAdded:Connect(renderKit))
						for _, v in column:GetChildren() do
							task.spawn(renderKit, v)
						end
					end
				end
			end
		end,
		Tooltip = 'Allows you to view opponent\'s kit in match draft.'
	})
end)

run(function()
	local KitESP
	local Background
	local Color = {}
	local Reference = {}
	local connections = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local ESPKits = {
		alchemist = {'alchemist_ingedients', 'wild_flower'},
		beekeeper = {'bee', 'bee'},
		bigman = {'treeOrb', 'natures_essence_1'},
		ghost_catcher = {'ghost', 'ghost_orb'},
		metal_detector = {'hidden-metal', 'iron'},
		sheep_herder = {'SheepModel', 'purple_hay_bale'},
		sorcerer = {'alchemy_crystal', 'wild_flower'},
		star_collector = {'stars', 'crit_star'}
	}
	
	local function Added(ent, icon)
		local part = ent:IsA('BasePart') and ent or ent:IsA('Model') and (ent.PrimaryPart or ent:FindFirstChild('Root') or ent:FindFirstChildWhichIsA('BasePart'))
		if not part or Reference[ent] then return end
	
		local billboard = Instance.new('BillboardGui')
		billboard.Name = icon
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		billboard.Parent = Folder
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local image = Instance.new('ImageLabel')
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = bedwars.getIcon({itemType = icon}, true)
		image.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = image
		Reference[ent] = billboard
	end
	
	KitESP = vape.Categories.Render:CreateModule({
		Name = 'KitESP',
		Function = function(callback)
			if callback then
				local current
				repeat
					if store.equippedKit ~= current then
						current = store.equippedKit
						for _, v in connections do
							v:Disconnect()
						end
						table.clear(connections)
						table.clear(Reference)
						Folder:ClearAllChildren()
	
						local kit = ESPKits[current]
						if kit then
							table.insert(connections, collectionService:GetInstanceAddedSignal(kit[1]):Connect(function(ent)
								Added(ent, kit[2])
							end))
							table.insert(connections, collectionService:GetInstanceRemovedSignal(kit[1]):Connect(function(ent)
								if Reference[ent] then
									Reference[ent]:Destroy()
									Reference[ent] = nil
								end
							end))
							for _, v in collectionService:GetTagged(kit[1]) do
								Added(v, kit[2])
							end
						end
					end
					task.wait(1)
				until not KitESP.Enabled
			else
				for _, v in connections do
					v:Disconnect()
				end
				table.clear(connections)
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'ESP for certain kit related objects'
	})
	
	Background = KitESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then
				Color.Object.Visible = callback
			end
			for _, v in Reference do
				v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = KitESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ImageLabel.BackgroundTransparency = 1 - (Background.Enabled and opacity or 0)
			end
		end,
		Darker = true
	})
end)

run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Rank
	local Enchant
	local Equipment
	local Inventory
	local InventoryList
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference, Refreshes = {}, {}, {}, {}
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	local methodused
	
	local function updateInventory(ent, nametag)
		local holder = ent.Player and nametag:FindFirstChild('Inventory')
		local inventory = holder and store.inventories[ent.Player]
		if not inventory then return end
	
		local shown = 0
		for _, v in inventory.items or {} do
			if #InventoryList.ListEnabled > 0 and not table.find(InventoryList.ListEnabled, v.itemType) then continue end
	
			shown += 1
			local icon = holder:FindFirstChild(tostring(shown))
			if not icon then
				icon = Instance.new('ImageLabel')
				icon.Name = tostring(shown)
				icon.Size = UDim2.fromOffset(24, 24)
				icon.BackgroundTransparency = 1
				icon.Parent = holder
				local amount = Instance.new('TextLabel')
				amount.Name = 'Amount'
				amount.Size = UDim2.fromOffset(23, 11)
				amount.Position = UDim2.fromOffset(0, 13)
				amount.BackgroundTransparency = 1
				amount.FontFace = nametag.FontFace
				amount.TextSize = 11
				amount.TextColor3 = Color3.new(1, 1, 1)
				amount.TextStrokeColor3 = Color3.new()
				amount.TextStrokeTransparency = 0.4
				amount.TextXAlignment = Enum.TextXAlignment.Right
				amount.Parent = icon
			end
	
			icon.LayoutOrder = shown
			icon.Visible = true
			icon.Image = bedwars.getIcon(v, true)
			icon.Amount.Text = (v.amount or 1) > 1 and tostring(v.amount) or ''
		end
	
		for _, v in holder:GetChildren() do
			if v:IsA('ImageLabel') and tonumber(v.Name) > shown then
				v.Visible = false
			end
		end
	end
	
	local Added = {
		Normal = function(ent)
			if not Targets.Players.Enabled and ent.Player then return end
			if not Targets.NPCs.Enabled and ent.NPC then return end
			if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
	
			local nametag = Instance.new('TextLabel')
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end
	
			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end
	
			if Equipment.Enabled then
				for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
					local Icon = Instance.new('ImageLabel')
					Icon.Name = v
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
					Icon.BackgroundTransparency = 1
					Icon.Image = ''
					Icon.Parent = nametag
				end
			end
	
			if Inventory.Enabled and ent.Player then
				local holder = Instance.new('Frame')
				holder.Name = 'Inventory'
				holder.AnchorPoint = Vector2.new(0.5, 0)
				holder.AutomaticSize = Enum.AutomaticSize.X
				holder.BackgroundTransparency = 1
				holder.Position = UDim2.new(0.5, 0, 1, 2)
				holder.Size = UDim2.fromOffset(0, 24)
				holder.Parent = nametag
				local layout = Instance.new('UIListLayout')
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout.Padding = UDim.new(0, 2)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = holder
			end
	
			nametag.TextSize = 14 * Scale.Value
			nametag.FontFace = FontOption.Value
			local size = getfontbounds(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace)
	
			task.spawn(function()
				if Rank.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'RankIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(size.X + 10, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.rank[ent.Player]:async() and bedwars.RankMeta[store.rank[ent.Player]:async()].image or ''
					Icon.Parent = nametag
				end
			end)
	
			task.spawn(function()
				if Enchant.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'EnchantIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(-30, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = store.enchants[ent.Player]:async() or ''
					Icon.Parent = nametag
				end
			end)
	
			nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = Background.Value
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = Distance.Enabled and entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
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
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				Refreshes[ent] = nil
				v:Destroy()
			end
		end,
		Drawing = function(ent)
			local v = Reference[ent]
			if v then
				Reference[ent] = nil
				Strings[ent] = nil
				Sizes[ent] = nil
				for _, v2 in v do
					pcall(function()
						v2.Visible = false
						v2:Remove()
					end)
				end
			end
		end
	}
	
	local Updated = {
		Normal = function(ent)
			local nametag = Reference[ent]
			if nametag then
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
	
				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end
	
				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end
	
				if Equipment.Enabled and store.inventories[ent.Player] then
					local kit = ent.Player:GetAttribute('PlayingAsKits')
					local kitmeta = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit]
					local inventory = store.inventories[ent.Player]
					local armor = {}
					for _, v in inventory.armor or {} do
						local itemmeta = typeof(v) == 'table' and bedwars.ItemMeta[v.itemType]
						if itemmeta and itemmeta.armor then
							armor[itemmeta.armor.slot] = v
						end
					end
	
					nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
					nametag.Helmet.Image = bedwars.getIcon(armor[0] or {itemType = ''}, true)
					nametag.Chestplate.Image = bedwars.getIcon(armor[1] or {itemType = ''}, true)
					nametag.Boots.Image = bedwars.getIcon(armor[2] or {itemType = ''}, true)
					nametag.Kit.Image = kitmeta and kitmeta.renderImage or ''
				end
	
				if Inventory.Enabled then
					updateInventory(ent, nametag)
				end
	
				if Enchant.Enabled and nametag:FindFirstChild('EnchantIcon') then
					nametag.EnchantIcon.Image = store.enchants[ent.Player]:async() or ''
				end
	
				local text = Distance.Enabled and entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				local size = getfontbounds(removeTags(text), nametag.TextSize, nametag.FontFace)
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				nametag.Text = text
			end
		end,
		Drawing = function(ent)
			local nametag = Reference[ent]
			if nametag then
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
	
				if Inventory.Enabled and i.Player and (Refreshes[i] or 0) < tick() then
					Refreshes[i] = tick() + 0.5
					store.inventories[i.Player] = bedwars.getInventory(i.Player)
					updateInventory(i, v)
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
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Inventory = NameTags:CreateToggle({
		Name = 'Inventory',
		Function = function(callback)
			if InventoryList then
				InventoryList.Object.Visible = callback
			end
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Tooltip = 'Shows how many of each listed item they are carrying'
	})
	InventoryList = NameTags:CreateTextList({
		Name = 'Inventory Items',
		Default = {'fireball', 'glue_projectile', 'telepearl', 'tnt'},
		Darker = true,
		Visible = false,
		Tooltip = 'Item types to count, empty shows everything they hold'
	})
	Enchant = NameTags:CreateToggle({
		Name = 'Show Enchant',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Rank = NameTags:CreateToggle({
		Name = 'Show Rank',
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
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
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
	local NoTextures
	local Materials = {}
	local Decals = {}
	local Meshes = {}
	local reference = {}
	
	local function remember(obj, property)
		local props = reference[obj]
		if not props then
			props = {}
			reference[obj] = props
		end
	
		if props[property] == nil then
			props[property] = obj[property]
		end
	end
	
	local function stripObject(obj)
		if Decals.Enabled and obj:IsA('Decal') then
			remember(obj, 'Transparency')
			obj.Transparency = 1
			return
		end
	
		if Decals.Enabled and obj:IsA('SurfaceAppearance') then
			remember(obj, 'Parent')
			obj.Parent = nil
			return
		end
	
		if Meshes.Enabled and obj:IsA('SpecialMesh') then
			remember(obj, 'TextureId')
			obj.TextureId = ''
			return
		end
	
		if obj:IsA('BasePart') then
			if Meshes.Enabled and obj:IsA('MeshPart') then
				remember(obj, 'TextureID')
				obj.TextureID = ''
			end
	
			if Materials.Enabled then
				remember(obj, 'Material')
				obj.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	
	local function scan()
		local descendants = store.map:GetDescendants()
		for i, v in descendants do
			if not NoTextures.Enabled then return end
			stripObject(v)
	
			if i % 500 == 0 then
				task.wait()
			end
		end
	end
	
	local function refresh()
		if not NoTextures.Enabled then return end
		for i, v in reference do
			pcall(function()
				for i2, v2 in v do
					i[i2] = v2
				end
			end)
		end
		table.clear(reference)
		scan()
	end
	
	NoTextures = vape.Categories.Render:CreateModule({
		Name = 'NoTextures',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.map or not NoTextures.Enabled
				if not NoTextures.Enabled then return end
	
				NoTextures:Clean(store.map.DescendantAdded:Connect(function(obj)
					task.defer(stripObject, obj)
				end))
				scan()
			else
				for i, v in reference do
					pcall(function()
						for i2, v2 in v do
							i[i2] = v2
						end
					end)
				end
				table.clear(reference)
			end
		end,
		Tooltip = 'Removes textures and materials from the map'
	})
	
	Materials = NoTextures:CreateToggle({
		Name = 'Materials',
		Function = refresh,
		Default = true,
		Tooltip = 'Flattens every part to smooth plastic'
	})
	Decals = NoTextures:CreateToggle({
		Name = 'Decals',
		Function = refresh,
		Default = true,
		Tooltip = 'Hides decals, textures and PBR surfaces'
	})
	Meshes = NoTextures:CreateToggle({
		Name = 'Meshes',
		Function = refresh,
		Default = true,
		Tooltip = 'Clears textures off meshes'
	})
end)

run(function()
	local OverlayEditor
	local FillColor
	local OutlineColor
	local Thickness
	local Animate
	local Speed
	local overlay, overlayBox, overlayTween
	local activePart
	
	local function bindPart(part)
		if not OverlayEditor.Enabled or not overlay then return end
		if not part:IsA('BasePart') or not part.Anchored or part.Transparency ~= 1 then return end
		local box = part:FindFirstChildOfClass('SelectionBox')
		if not box then return end
	
		box.Visible = false
		activePart = part
		if overlayTween then
			overlayTween:Cancel()
			overlayTween = nil
		end
	
		if Animate.Enabled and overlay.Parent == gameCamera then
			overlayTween = tweenService:Create(overlay, TweenInfo.new(Speed.Value, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = part.CFrame,
				Size = part.Size
			})
			overlayTween:Play()
		else
			overlay.CFrame = part.CFrame
			overlay.Size = part.Size
			overlay.Parent = gameCamera
		end
	end
	
	OverlayEditor = vape.Categories.Render:CreateModule({
		Name = 'OverlayEditor',
		Function = function(callback)
			if callback then
				overlay = Instance.new('Part')
				overlay.Size = Vector3.one * 3
				overlay.Anchored = true
				overlay.CanCollide = false
				overlay.CanQuery = false
				overlay.CanTouch = false
				overlay.CastShadow = false
				overlay.Transparency = 1
				overlayBox = Instance.new('SelectionBox')
				overlayBox.Adornee = overlay
				overlayBox.LineThickness = Thickness.Value
				overlayBox.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				overlayBox.Transparency = 1 - OutlineColor.Opacity
				overlayBox.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				overlayBox.SurfaceTransparency = 1 - FillColor.Opacity
				overlayBox.Parent = overlay
				bedwars.QueryUtil:setQueryIgnored(overlay, true)
	
				for _, v in workspace:GetChildren() do
					bindPart(v)
				end
	
				OverlayEditor:Clean(workspace.ChildAdded:Connect(function(child)
					task.defer(bindPart, child)
				end))
				OverlayEditor:Clean(workspace.ChildRemoved:Connect(function(child)
					if child ~= activePart then return end
	
					activePart = nil
					task.delay(0.06, function()
						if activePart or not OverlayEditor.Enabled then return end
						if overlayTween then
							overlayTween:Cancel()
							overlayTween = nil
						end
						if overlay then
							overlay.Parent = nil
						end
					end)
				end))
			else
				if activePart then
					local box = activePart:FindFirstChildOfClass('SelectionBox')
					if box then
						box.Visible = true
					end
					activePart = nil
				end
	
				if overlayTween then
					overlayTween:Cancel()
					overlayTween = nil
				end
				if overlay then
					overlay:Destroy()
					overlay, overlayBox = nil, nil
				end
			end
		end,
		Tooltip = 'Restyles the outline on the block you are aiming at'
	})
	
	FillColor = OverlayEditor:CreateColorSlider({
		Name = 'Fill Color',
		DefaultSat = 0,
		DefaultOpacity = 0.25,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			if overlayBox then
				overlayBox.SurfaceColor3 = Color3.fromHSV(hue, sat, val)
				overlayBox.SurfaceTransparency = 1 - opacity
			end
		end
	})
	OutlineColor = OverlayEditor:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			if overlayBox then
				overlayBox.Color3 = Color3.fromHSV(hue, sat, val)
				overlayBox.Transparency = 1 - opacity
			end
		end
	})
	Thickness = OverlayEditor:CreateSlider({
		Name = 'Thickness',
		Min = 0.01,
		Max = 0.2,
		Decimal = 100,
		Function = function(value)
			if overlayBox then
				overlayBox.LineThickness = value
			end
		end,
		Default = 0.04
	})
	Animate = OverlayEditor:CreateToggle({
		Name = 'Animate',
		Default = true,
		Tooltip = 'Glides the overlay onto the next block instead of snapping to it'
	})
	Speed = OverlayEditor:CreateSlider({
		Name = 'Animation time',
		Min = 0.01,
		Max = 0.5,
		Default = 0.08,
		Decimal = 100,
		Suffix = 's'
	})
end)

run(function()
	local PotESP
	local Background
	local Color = {}
	local Reference = {}
	local Template
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(block)
		if block.Name ~= 'desert_pot' or Reference[block] then return end
	
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = block.Name
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = block
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local viewport = Instance.new('ViewportFrame')
		viewport.Size = UDim2.fromOffset(36, 36)
		viewport.Position = UDim2.fromScale(0.5, 0.5)
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
		viewport.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		viewport.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		viewport.BorderSizePixel = 0
		viewport.Ambient = Color3.new(1, 1, 1)
		viewport.LightColor = Color3.new(1, 1, 1)
		viewport.Parent = billboard
		local uicorner = Instance.new('UICorner')
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = viewport
	
		if Template == nil then
			local assets = replicatedStorage:FindFirstChild('Assets')
			local blocks = assets and assets:FindFirstChild('Blocks')
			local model = blocks and blocks:FindFirstChild('desert_pot')
			Template = model and model:FindFirstChildWhichIsA('MeshPart', true) or false
		end
	
		if Template then
			local mesh = Template:Clone()
			mesh.CFrame = CFrame.Angles(0, math.rad(25), 0)
			mesh.Parent = viewport
			local camera = Instance.new('Camera')
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.75, 3.9), Vector3.new(0, 0.05, 0))
			camera.Parent = viewport
			viewport.CurrentCamera = camera
		end
	
		Reference[block] = billboard
	end
	
	PotESP = vape.Categories.Render:CreateModule({
		Name = 'PotESP',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('block') do
					Added(v)
				end
				PotESP:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(Added))
				PotESP:Clean(collectionService:GetInstanceRemovedSignal('block'):Connect(function(block)
					if Reference[block] then
						Reference[block]:Destroy()
						Reference[block] = nil
					end
				end))
			else
				for i, v in Reference do
					v:Destroy()
					Reference[i] = nil
				end
			end
		end,
		Tooltip = 'Renders an icon over desert pots'
	})
	
	Background = PotESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then
				Color.Object.Visible = callback
			end
			for _, v in Reference do
				v.ViewportFrame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = PotESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.ViewportFrame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.ViewportFrame.BackgroundTransparency = 1 - (Background.Enabled and opacity or 0)
			end
		end,
		Darker = true
	})
end)

run(function()
	local BulletTracers
	local Material
	local Lifetime
	local Curve
	local Opacity
	local Thickness
	local Color
	local Fade
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	BulletTracers = vape.Categories.Render:CreateModule({
		Name = 'ProjectileTracers',
		Function = function(callback)
			if callback then
				BulletTracers:Clean(workspace.ChildAdded:Connect(function(projectile)
					task.delay(0, function()
						if not BulletTracers.Enabled or not projectile.Parent or projectile:GetAttribute('ProjectileShooter') ~= lplr.UserId then
							return
						end
						local filter = {projectile}
						if lplr.Character then table.insert(filter, lplr.Character) end
						rayCheck.FilterDescendantsInstances = filter
						local root = projectile:IsA('BasePart') and projectile or projectile:IsA('Model') and projectile.PrimaryPart
						local meta = bedwars.ProjectileMeta[projectile.Name]
						if not root or not meta then return end
						local origin = root.Position
						local velocity = root.AssemblyLinearVelocity
						local velocityMagnitude = velocity.Magnitude
						if velocityMagnitude <= 0 then
							return
						end
						local velocityUnit = velocity / velocityMagnitude
						local gravity = meta.gravitationalAcceleration or workspace.Gravity
						local ray = workspace:Raycast(origin, velocityUnit * 2000, rayCheck)
						local endpoint = ray and ray.Position or (origin + velocityUnit * 2000)
						local travelTime = (endpoint - origin).Magnitude / velocityMagnitude
						prediction.SpawnArcTracer(origin, velocityUnit, velocityMagnitude, gravity, travelTime, Curve.Value, {
							Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value),
							Transparency = Opacity.Value,
							Thick = Thickness.Value,
							Material = Enum.Material[Material.Value],
							Lifetime = Lifetime.Value,
							Fade = Fade.Enabled
						})
					end)
				end))
			end
		end,
		Tooltip = 'Replacement tracers for projectiles'
	})
	
	local materials = {'SmoothPlastic'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'SmoothPlastic' then
			table.insert(materials, v.Name)
		end
	end
	Material = BulletTracers:CreateDropdown({
		Name = 'Material',
		List = materials
	})
	Color = BulletTracers:CreateColorSlider({
		Name = 'Tracer Color',
		DefaultOpacity = 0.5
	})
	Thickness = BulletTracers:CreateSlider({
		Name = 'Thickness',
		Min = 0.01,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	Curve = BulletTracers:CreateSlider({
		Name = 'Curveness',
		Min = 1,
		Max = 100,
		Default = 40,
		Tooltip = 'How curve the projectile is gonna be\n(More curve = more lag)'
	})
	Opacity = BulletTracers:CreateSlider({
		Name = 'Opacity',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100
	})
	Lifetime = BulletTracers:CreateSlider({
		Name = 'Lifetime',
		Min = 0,
		Max = 5,
		Decimal = 100,
		Default = 2,
		Suffix = 'secs'
	})
	Fade = BulletTracers:CreateToggle({
		Name = 'Fade',
		Default = true
	})
end)

run(function()
	local SkinChanger
	local Options = {}
	local skins, families, groups, order = {}, {}, {}, {}
	local names, extras = {}, {}
	local sounds = {}
	local added = setmetatable({}, {__mode = 'k'})
	local watching, lasthand, queued
	local tiers = {leather = true, chainmail = true, wood = true, stone = true, gold = true, iron = true, diamond = true, emerald = true}
	
	for _, v in bedwars.ItemSkinType do
		local meta = bedwars.getItemSkinMeta(v)
		local item = meta and meta.itemType and bedwars.ItemMeta[meta.itemType]
		if item and not item.block then
			local label = `_{v}_`
			for i in meta.itemType:gmatch('[^_]+') do
				label = label:gsub(`_{i}_`, '_')
			end
			label = label:gsub('^_+', ''):gsub('_+$', '')
			label = (tostring(label ~= '' and label or v):gsub('_', ' '):gsub('%a+', function(word)
				return `{word:sub(1, 1):upper()}{word:sub(2)}`
			end))
	
			skins[meta.itemType] = skins[meta.itemType] or {}
			skins[meta.itemType][label] = v
		end
	end
	
	for i in skins do
		local family = i:gsub('_%d+$', '')
		local tier, base = family:match('^([^_]+)_(.+)$')
		family = tier and tiers[tier] and base or family
		if not groups[family] then
			groups[family] = {}
			table.insert(order, family)
		end
		families[i] = family
		table.insert(groups[family], i)
	end
	
	for i, v in groups do
		names[i] = (tostring(#v > 1 and i or v[1]):gsub('_', ' '):gsub('%a+', function(word)
			return `{word:sub(1, 1):upper()}{word:sub(2)}`
		end))
	end
	table.sort(order, function(a, b)
		return names[a] < names[b]
	end)
	
	for _, v in {'lobby_kaida_claw', 'bear_claws', 'summoner_claw_1', 'summoner_claw_2', 'summoner_claw_3', 'summoner_claw_4'} do
		if replicatedStorage.Items:FindFirstChild(v) then
			local label = (tostring((v:gsub('^lobby_', ''))):gsub('_', ' '):gsub('%a+', function(word)
				return `{word:sub(1, 1):upper()}{word:sub(2)}`
			end))
			extras[label] = v
		end
	end
	
	local function applyModel(accessory)
		local family = SkinChanger.Enabled and families[accessory.Name]
		local option = family and Options[family]
		local label = option and option.Value
		local model = label and (extras[label] or skins[accessory.Name][label]) or nil
		local handle = accessory:FindFirstChild('Handle')
		local template = replicatedStorage.Items:FindFirstChild(model or '')
		if not handle or not template or added[accessory] then return end
	
		local grip = handle:FindFirstChild('RightGripAttachment')
		local templategrip = template.Handle:FindFirstChild('RightGripAttachment')
		local record = {
			Parts = {},
			Size = handle.Size,
			Grip = grip and grip.CFrame or nil
		}
		added[accessory] = record
	
		for _, v in handle:GetChildren() do
			if v:IsA('BasePart') and v:GetAttribute('SkinHidden') == nil then
				v:SetAttribute('SkinHidden', v.Transparency)
				v.Transparency = 1
			end
		end
	
		if handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
			handle:ApplyMesh(template.Handle)
		end
		handle.Size = template.Handle.Size
		if grip and templategrip then
			grip.CFrame = templategrip.CFrame
		end
	
		for _, v in template.Handle:GetChildren() do
			if v:IsA('BasePart') then
				local part = v:Clone()
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Massless = true
				part.CFrame = handle.CFrame * (template.Handle.CFrame:Inverse() * v.CFrame)
				part.Parent = handle
	
				local weld = Instance.new('WeldConstraint')
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
				table.insert(record.Parts, part)
			end
		end
	end
	
	local function applySkins()
		for i in skins do
			local meta = bedwars.ItemMeta[i]
			if meta and meta.sword then
				local family = SkinChanger.Enabled and families[i]
				local option = family and Options[family]
				local label = option and option.Value
				local skin = label and not extras[label] and skins[i][label] or nil
				local skinmeta = skin and bedwars.getItemSkinMeta(skin)
				local sword = skinmeta and skinmeta.sword
				if sword and (sword.swingSounds or sword.hitSounds) then
					if not sounds[i] then
						sounds[i] = {swing = meta.sword.swingSounds, hit = meta.sword.hitSounds}
					end
					meta.sword.swingSounds = sword.swingSounds or sounds[i].swing
					meta.sword.hitSounds = sword.hitSounds or sounds[i].hit
				elseif sounds[i] then
					meta.sword.swingSounds = sounds[i].swing
					meta.sword.hitSounds = sounds[i].hit
					sounds[i] = nil
				end
			end
		end
	
		local inventory = store.inventory.inventory
		local changed = false
		for _, v in inventory.items do
			local family = SkinChanger.Enabled and families[v.itemType]
			local option = family and Options[family]
			local label = option and option.Value
			local skin = label and not extras[label] and skins[v.itemType][label] or nil
			if v.itemSkin ~= skin then
				v.itemSkin = skin
				changed = true
			end
		end
		if inventory.hand then
			local family = SkinChanger.Enabled and families[inventory.hand.itemType]
			local option = family and Options[family]
			local label = option and option.Value
			local skin = label and not extras[label] and skins[inventory.hand.itemType][label] or nil
			if inventory.hand.itemSkin ~= skin then
				inventory.hand.itemSkin = skin
				changed = true
			end
		end
	
		local hand = inventory.hand and inventory.hand.itemType
		if not changed and hand == lasthand then return end
	
		lasthand = hand
		bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
		if not lplr.Character then return end
	
		for _, v in lplr.Character:GetChildren() do
			if not v:IsA('Accessory') then continue end
	
			local record = added[v]
			if record then
				local handle = v:FindFirstChild('Handle')
				local template = replicatedStorage.Items:FindFirstChild(v.Name)
				for _, v2 in record.Parts do
					v2:Destroy()
				end
	
				for _, v2 in handle and handle:GetChildren() or {} do
					local transparency = v2:GetAttribute('SkinHidden')
					if transparency then
						v2.Transparency = transparency
						v2:SetAttribute('SkinHidden', nil)
					end
				end
				added[v] = nil
	
				if handle then
					if template and handle:IsA('MeshPart') and template.Handle:IsA('MeshPart') then
						handle:ApplyMesh(template.Handle)
					end
					handle.Size = record.Size
	
					local grip = handle:FindFirstChild('RightGripAttachment')
					if grip and record.Grip then
						grip.CFrame = record.Grip
					end
				end
			end
	
			applyModel(v)
		end
	end
	
	local function queueSkins()
		if queued then return end
	
		queued = true
		task.defer(function()
			queued = false
			applySkins()
		end)
	end
	
	SkinChanger = vape.Categories.Render:CreateModule({
		Name = 'SkinChanger',
		Function = function(callback)
			if callback then
				SkinChanger:Clean(vapeEvents.InventoryChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(queueSkins))
				SkinChanger:Clean(lplr.CharacterAdded:Connect(function(char)
					lasthand = nil
					if watching then
						watching:Disconnect()
					end
					watching = char.ChildAdded:Connect(function(v)
						if v:IsA('Accessory') and v:WaitForChild('Handle', 3) and SkinChanger.Enabled then
							applyModel(v)
						end
					end)
	
					task.spawn(function()
						for _ = 1, 10 do
							task.wait(0.4)
							if not SkinChanger.Enabled then return end
							applySkins()
						end
					end)
				end))
	
				if lplr.Character then
					if watching then
						watching:Disconnect()
					end
					watching = lplr.Character.ChildAdded:Connect(function(v)
						if v:IsA('Accessory') and v:WaitForChild('Handle', 3) and SkinChanger.Enabled then
							applyModel(v)
						end
					end)
				end
			elseif watching then
				watching:Disconnect()
				watching = nil
			end
			applySkins()
		end,
		Tooltip = 'Reskins the items you hold with their sounds, only you can see it'
	})
	
	for _, v in order do
		local list, seen = {}, {}
		for _, v2 in groups[v] do
			for i2 in skins[v2] do
				if not seen[i2] then
					seen[i2] = true
					table.insert(list, i2)
				end
			end
		end
	
		local melee = false
		for _, v2 in groups[v] do
			local meta = bedwars.ItemMeta[v2]
			if meta and meta.sword then
				melee = true
				break
			end
		end
	
		if melee then
			for i2 in extras do
				table.insert(list, i2)
			end
		end
	
		table.sort(list)
		table.insert(list, 1, 'None')
		Options[v] = SkinChanger:CreateDropdown({
			Name = names[v],
			List = list,
			Function = function()
				if SkinChanger.Enabled then
					applySkins()
				end
			end
		})
	end
end)

run(function()
	local StorageESP
	local List
	local ShowAmount
	local Background
	local Color = {}
	local Reference = {}
	local Connections = setmetatable({}, {__mode = 'k'})
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function refreshAdornee(billboard)
		local chest = billboard.Adornee and billboard.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value
		if not chest then
			billboard.Enabled = false
			return
		end
	
		for _, v in Connections[billboard] or {} do
			v:Disconnect()
		end
		Connections[billboard] = {}
		for _, v in billboard.Frame:GetChildren() do
			if v:IsA('ImageLabel') then
				v:Destroy()
			end
		end
	
		local amounts = {}
		for _, v in chest:GetChildren() do
			amounts[v.Name] = (amounts[v.Name] or 0) + (v:GetAttribute('Amount') or 0)
			if ShowAmount.Enabled then
				table.insert(Connections[billboard], v:GetAttributeChangedSignal('Amount'):Connect(function()
					refreshAdornee(billboard)
				end))
			end
		end
	
		local alreadygot = {}
		billboard.Enabled = false
		for _, v in chest:GetChildren() do
			if alreadygot[v.Name] then continue end
			for _, v2 in List.ListEnabled do
				if v.Name:find(v2, 1, true) then
					alreadygot[v.Name] = true
					billboard.Enabled = true
					local blockimage = Instance.new('ImageLabel')
					blockimage.Size = UDim2.fromOffset(32, 32)
					blockimage.BackgroundTransparency = 1
					blockimage.Image = bedwars.getIcon({itemType = v.Name}, true)
					blockimage.Parent = billboard.Frame
					if ShowAmount.Enabled and amounts[v.Name] > 1 then
						local amount = Instance.new('TextLabel')
						amount.Name = 'Amount'
						amount.Size = UDim2.fromOffset(31, 14)
						amount.Position = UDim2.fromOffset(0, 18)
						amount.BackgroundTransparency = 1
						amount.Text = tostring(amounts[v.Name])
						amount.TextXAlignment = Enum.TextXAlignment.Right
						amount.TextSize = 14
						amount.TextColor3 = uipallet.Text
						amount.TextStrokeColor3 = Color3.new()
						amount.TextStrokeTransparency = 0.4
						amount.FontFace = uipallet.Font
						amount.Parent = blockimage
					end
					break
				end
			end
		end
	end
	
	local function Added(part)
		local chest = part:WaitForChild('ChestFolderValue', 3)
		chest = chest and chest.Value
		if not chest or not StorageESP.Enabled or Reference[part] then return end
	
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[part] = billboard
	
		StorageESP:Clean(chest.ChildAdded:Connect(function()
			refreshAdornee(billboard)
		end))
		StorageESP:Clean(chest.ChildRemoved:Connect(function()
			refreshAdornee(billboard)
		end))
		refreshAdornee(billboard)
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(function(part)
					task.spawn(Added, part)
				end))
				StorageESP:Clean(collectionService:GetInstanceRemovedSignal('chest'):Connect(function(part)
					if Reference[part] then
						Reference[part]:Destroy()
						Reference[part] = nil
					end
				end))
				for _, v in collectionService:GetTagged('chest') do
					task.spawn(Added, v)
				end
			else
				for _, v in Connections do
					for _, v2 in v do
						v2:Disconnect()
					end
				end
				table.clear(Connections)
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			for _, v in Reference do
				task.spawn(refreshAdornee, v)
			end
		end
	})
	ShowAmount = StorageESP:CreateToggle({
		Name = 'Show Amount',
		Function = function()
			for _, v in Reference do
				task.spawn(refreshAdornee, v)
			end
		end,
		Tooltip = 'Displays how much of each item the chest holds'
	})
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then
				Color.Object.Visible = callback
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = StorageESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - (Background.Enabled and opacity or 0)
			end
		end,
		Darker = true
	})
end)

run(function()
	local ComboCounter
	local ComboComparator
	local DamageComparator
	local combo, comparator = 0, 0
	local dealt, dealthits, taken, takenhits = 0, 0, 0, 0
	
	ComboCounter = targetinfo:CreateStat({
		Name = 'Combo Counter',
		Icon = getvapeasset('catsix/assets/new/combo_display.png'),
		IconSize = UDim2.fromOffset(14, 12),
		Default = true,
		Tooltip = 'Shows how many hits in a direct row you have landed on, or taken from, the target.'
	})
	ComboComparator = targetinfo:CreateStat({
		Name = 'Combo Comparator',
		Icon = getvapeasset('catsix/assets/new/sword_header.png'),
		IconSize = UDim2.fromOffset(12, 12),
		Signed = true,
		Tooltip = 'Measures how many hits you have landed compared to the target.'
	})
	DamageComparator = targetinfo:CreateStat({
		Name = 'Damage Comparator',
		Default = true,
		Signed = true,
		Tint = true,
		Tooltip = 'Measures the strength of the target compared to yourself, from the damage each of you lands per hit.'
	})
	vape:Clean(targetinfo.TargetChanged:Connect(function()
		combo, comparator = 0, 0
		dealt, dealthits, taken, takenhits = 0, 0, 0, 0
	end))
	vape:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
		local target = targetinfo.LastTarget
		if not target or not target.Character then return end
	
		local landed = damageTable.fromEntity == lplr.Character and damageTable.entityInstance == target.Character
		local received = damageTable.entityInstance == lplr.Character and damageTable.fromEntity == target.Character
		if not landed and not received then return end
	
		if landed then
			combo = combo >= 0 and combo + 1 or 0
			comparator += 1
			dealt += damageTable.damage or 0
			dealthits += 1
		else
			combo = combo <= 0 and combo - 1 or 0
			comparator -= 1
			taken += damageTable.damage or 0
			takenhits += 1
		end
	
		targetinfo:SetStat(ComboCounter, combo)
		targetinfo:SetStat(ComboComparator, comparator)
		targetinfo:SetStat(DamageComparator, math.clamp(math.round((dealthits > 0 and dealt / dealthits or 0) - (takenhits > 0 and taken / takenhits or 0)), -9, 9))
	end))
end)

run(function()
	local TeamUpgrades
	local OwnTeam
	local BedUpgrades
	local Color
	local Transparency
	local Scale
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local numerals = {'I', 'II', 'III', 'IV', 'V'}
	
	local function getAnchor(obj)
		return obj:IsA('Model') and (obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart')) or obj
	end
	
	local function getText(team)
		local state = bedwars.Store:getState().Bedwars
		local upgrades = state.teamUpgrades[team] or {}
		local bought = {}
	
		for i, v in bedwars.TeamUpgradeMeta do
			local tier = upgrades[i]
			if tier and tier > 0 then
				table.insert(bought, `{v.name} {numerals[tier] or tier}`)
			end
		end
	
		table.sort(bought)
	
		if BedUpgrades.Enabled then
			local bed = state.bedTeamUpgrades[team] or {}
			if bed.bed_shield then
				table.insert(bought, 'Bed Shield')
			end
			if bed.bed_alarm then
				table.insert(bought, 'Bed Alarm')
			end
		end
	
		return `Team {team} | {#bought > 0 and table.concat(bought, ', ') or 'No upgrades'}`
	end
	
	local function Added(obj, tag)
		local team = tag:match('^(%d+)_TeamOreGenerator')
		local anchor = team and getAnchor(obj)
		if not anchor then return end
		if not OwnTeam.Enabled and team == lplr:GetAttribute('Team') then return end
	
		local nametag = Instance.new('TextLabel')
		nametag.Name = `Team{team}`
		nametag.Text = getText(team)
		nametag.TextSize = 14 * Scale.Value
		nametag.Font = Enum.Font.Arial
		local size = getfontbounds(nametag.Text, nametag.TextSize, nametag.FontFace)
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Transparency.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.Parent = Folder
		Reference[anchor] = {Label = nametag, Team = team}
	end
	
	local function refresh()
		for _, v in Reference do
			v.Label.Text = getText(v.Team)
			local size = getfontbounds(v.Label.Text, v.Label.TextSize, v.Label.FontFace)
			v.Label.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		end
	end
	
	TeamUpgrades = vape.Categories.Render:CreateModule({
		Name = 'TeamUpgrades',
		Function = function(callback)
			if callback then
				for _, tag in collectionService:GetAllTags() do
					if tag:match('^%d+_TeamOreGenerator$') then
						for _, v in collectionService:GetTagged(tag) do
							Added(v, tag)
						end
						TeamUpgrades:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
							Added(obj, tag)
						end))
					end
				end
	
				TeamUpgrades:Clean(runService.PreRender:Connect(function()
					for i, v in Reference do
						if not i.Parent then
							v.Label:Destroy()
							Reference[i] = nil
							continue
						end
	
						local screenPos, visible = gameCamera:WorldToViewportPoint(i.Position + Vector3.new(0, 4, 0))
						v.Label.Visible = visible
						if not visible then continue end
						v.Label.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
					end
				end))
	
				repeat
					refresh()
					task.wait(0.5)
				until not TeamUpgrades.Enabled
			else
				for i, v in Reference do
					v.Label:Destroy()
					Reference[i] = nil
				end
			end
		end,
		Tooltip = 'Puts every teams upgrades over their generator, and whether their bed is shielded or alarmed which the game never shows you anywhere'
	})
	
	OwnTeam = TeamUpgrades:CreateToggle({
		Name = 'Show own team',
		Function = function()
			if TeamUpgrades.Enabled then
				TeamUpgrades:Toggle()
				TeamUpgrades:Toggle()
			end
		end
	})
	BedUpgrades = TeamUpgrades:CreateToggle({
		Name = 'Bed upgrades',
		Default = true,
		Function = function()
			if TeamUpgrades.Enabled then
				refresh()
			end
		end,
		Tooltip = 'Bed shield and bed alarm, which no part of the games own UI displays'
	})
	Color = TeamUpgrades:CreateColorSlider({
		Name = 'Text Color',
		Function = function(hue, sat, val)
			for _, v in Reference do
				v.Label.TextColor3 = Color3.fromHSV(hue, sat, val)
			end
		end,
		DefaultSat = 0,
		DefaultValue = 1
	})
	Transparency = TeamUpgrades:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.5,
		Function = function(value)
			for _, v in Reference do
				v.Label.BackgroundTransparency = value
			end
		end
	})
	Scale = TeamUpgrades:CreateSlider({
		Name = 'Scale',
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Default = 1,
		Function = function(value)
			for _, v in Reference do
				v.Label.TextSize = 14 * value
				local size = getfontbounds(v.Label.Text, v.Label.TextSize, v.Label.FontFace)
				v.Label.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			end
		end
	})
	
end)

run(function()
	local AntiEffect
	local Dizzy
	local Fear
	local Vignettes
	local oldvignettes
	
	AntiEffect = vape.Categories.Utility:CreateModule({
		Name = 'AntiEffect',
		Function = function(callback)
			if callback then
				if Dizzy.Enabled then
					runService:UnbindFromRenderStep('dizzy-status')
				end
	
				if Fear.Enabled then
					runService:UnbindFromRenderStep('werewolf-fear-status')
				end
	
				if Vignettes.Enabled then
					oldvignettes = bedwars.VignetteController.enableOnScreenEffects
					bedwars.VignetteController.enableOnScreenEffects = false
					bedwars.VignetteController:destroyAllVignettes()
				end
	
				local added = bedwars.SyncEvents.StatusEffectAdded:setPriority(1000):connect(function(event)
					if event.entityInstance ~= lplr.Character then return end
	
					if Dizzy.Enabled and event.statusEffect == bedwars.StatusEffectMeta.DIZZY then
						runService:UnbindFromRenderStep('dizzy-status')
					end
	
					if Fear.Enabled and event.statusEffect == bedwars.StatusEffectMeta.WEREWOLF_FEAR then
						runService:UnbindFromRenderStep('werewolf-fear-status')
					end
				end)
				AntiEffect:Clean(function()
					added:Destroy()
				end)
			else
				if oldvignettes ~= nil then
					bedwars.VignetteController.enableOnScreenEffects = oldvignettes
					oldvignettes = nil
				end
			end
		end,
		Tooltip = 'Throws away the parts of a debuff the game plays on your own client'
	})
	
	Dizzy = AntiEffect:CreateToggle({
		Name = 'Dizzy',
		Default = true,
		Tooltip = 'Stops the dizzy toad swinging your walk direction around, the slow itself is on the server'
	})
	Fear = AntiEffect:CreateToggle({
		Name = 'Werewolf fear',
		Default = true,
		Tooltip = 'Stops the werewolf tail walking you away from it'
	})
	Vignettes = AntiEffect:CreateToggle({
		Name = 'Vignettes',
		Function = function(callback)
			if AntiEffect.Enabled and callback then
				oldvignettes = bedwars.VignetteController.enableOnScreenEffects
				bedwars.VignetteController.enableOnScreenEffects = false
				bedwars.VignetteController:destroyAllVignettes()
			elseif AntiEffect.Enabled and oldvignettes ~= nil then
				bedwars.VignetteController.enableOnScreenEffects = oldvignettes
				oldvignettes = nil
			end
		end,
		Default = true,
		Tooltip = 'Clears the coloured screen border frozen, decay, soaked and the rest put over your view'
	})
end)

run(function()
	local AntiLasso
	local Chance
	local Check
	local watching = setmetatable({}, {__mode = 'k'})
	
	local function Added(ent)
		if watching[ent] then return end
	
		watching[ent] = ent.ChildAdded:Connect(function(v)
			if v:IsA('Accessory') and v:FindFirstChild('Rope') and Random.new(os.clock()):NextNumber(1, 100) < Chance.Value and (not Check.Enabled or entitylib.EntityPosition({
				Range = 50,
				Part = 'RootPart',
				Players = true
			})) then
				ent.PrimaryPart.Anchored = true
				v.Destroying:Once(function()
					task.wait(0.5)
					ent.PrimaryPart.Anchored = false
				end)
			end
		end)
	end
	
	AntiLasso = vape.Categories.Utility:CreateModule({
		Name = 'AntiLasso',
		Function = function(callback)
			if callback then
				AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					task.delay(1, function()
						Added(ent.Character)
					end)
				end))
				if entitylib.isAlive then
					Added(lplr.Character)
				end
			end
		end,
		Tooltip = 'Prevents you from getting pulled by lasso projectile.'
	})
	
	Chance = AntiLasso:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	Check = AntiLasso:CreateToggle({Name = 'Only when targeting'})
end)

run(function()
	local AntiSuffocate
	local Mode
	local Height
	
	local offsets = {
		Vector3.new(0, 3, 0),
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(0, 0, -3),
		Vector3.new(0, -3, 0)
	}
	
	local function getEscape(position)
		for _, v in offsets do
			local target = position + v
			if not getPlacedBlock(target) and not getPlacedBlock(target + Vector3.new(0, 3, 0)) then
				return target
			end
		end
		return nil
	end
	
	AntiSuffocate = vape.Categories.Utility:CreateModule({
		Name = 'AntiSuffocate',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.matchState == 1 then
						local root = entitylib.character.RootPart
						local head = root.Position + Vector3.new(0, Height.Value, 0)
						if getPlacedBlock(head) then
							if Mode.Value == 'Break' then
								local block = getPlacedBlock(head)
								if block then
									bedwars.breakBlock(block, true, true)
								end
							else
								local escape = getEscape(roundPos(head))
								if escape then
									root.CFrame = CFrame.new(escape - Vector3.new(0, Height.Value, 0)) * (root.CFrame - root.Position)
									root.AssemblyLinearVelocity = Vector3.zero
								end
							end
						end
					end
					task.wait(0.1)
				until not AntiSuffocate.Enabled
			end
		end,
		Tooltip = 'Gets you out of a block that someone placed on top of you before it suffocates you'
	})
	
	Mode = AntiSuffocate:CreateDropdown({
		Name = 'Mode',
		List = {'Move', 'Break'},
		Tooltip = 'Move - shifts you into the nearest open cell\nBreak - breaks the block you are stuck in'
	})
	Height = AntiSuffocate:CreateSlider({
		Name = 'Check height',
		Min = 0,
		Max = 4,
		Default = 1.5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far above your root the check looks, 1.5 is head level'
	})
end)

run(function()
	local AutoBalloon
	
	AutoBalloon = vape.Categories.Utility:CreateModule({
		Name = 'AutoBalloon',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
				if not AutoBalloon.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
							local balloon = getItem('balloon')
							if balloon then
								for _ = 1, 3 do
									bedwars.BalloonController:inflateBalloon()
								end
							end
							task.wait(0.1)
						end
					end
					task.wait(0.1)
				until not AutoBalloon.Enabled
			end
		end,
		Tooltip = 'Inflates when you fall into the void'
	})
end)

run(function()
	local AutoBlockUp
	local LimitItem
	local lastPlace = 0
	local up = false
	
	AutoBlockUp = vape.Categories.Utility:CreateModule({
		Name = 'AutoBlockUp',
		Function = function(callback)
			if callback then
				AutoBlockUp:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive and up then
						local item
						if store.hand.toolType == 'block' and (store.hand.amount or 0) > 0 then
							item = store.hand.tool and store.hand.tool.Name
						elseif not LimitItem.Enabled then
							for _, v in store.inventory.inventory.items do
								local meta = bedwars.ItemMeta[v.itemType]
								if meta and meta.block and (v.amount or 0) > 0 then
									item = v.itemType
									break
								end
							end
						end
	
						if item then
							local pos = roundPos(entitylib.character.RootPart.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
							if tick() >= lastPlace and not getPlacedBlock(pos) then
								lastPlace = tick() + 0.15
								bedwars.placeBlock(pos, item, false)
							end
	
							entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(entitylib.character.RootPart.AssemblyLinearVelocity.X, 35, entitylib.character.RootPart.AssemblyLinearVelocity.Z)
						end
					end
				end))
				AutoBlockUp:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
						up = true
					end
				end))
				AutoBlockUp:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = false
						entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(entitylib.character.RootPart.AssemblyLinearVelocity.X, 0, entitylib.character.RootPart.AssemblyLinearVelocity.Z)
					end
				end))
	
				local touchGui = inputService.TouchEnabled and lplr.PlayerGui:FindFirstChild('TouchGui')
				local jumpButton = touchGui and touchGui:FindFirstChild('JumpButton', true)
				if jumpButton then
					AutoBlockUp:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
						up = jumpButton.ImageRectOffset.X == 146
					end))
				end
			end
		end,
		Tooltip = 'Places a block beneath you while holding jump so you can tower up instantly'
	})
	
	LimitItem = AutoBlockUp:CreateToggle({Name = 'Limit to items'})
end)

run(function()
	local AutoCollect
	local Collectables
	local Range
	local Delay
	local Animation
	
	local Request = bedwars.Handler:Get('CollectCollectableEntity')
	local cooldowns = {}
	
	AutoCollect = vape.Categories.Utility:CreateModule({
		Name = 'AutoCollect',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in Collectables.ListEnabled do
							for _, v2 in collectionService:GetTagged(v) do
								local part = v2:IsA('Model') and v2.PrimaryPart or v2
								local id = v2:GetAttribute('Id')
								if part and id and tick() > (cooldowns[v2] or 0) and (localPosition - part.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									end
	
									Request:Fire('SendToServer', {
										id = id,
										collectableName = v2.Name
									})
									cooldowns[v2] = tick() + 1
								end
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoCollect.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Picks up every kit collectable near you without walking into it'
	})
	
	Range = AutoCollect:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 11,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'The server drops collects past 12 studs'
	})
	Delay = AutoCollect:CreateSlider({
		Name = 'Delay',
		Min = 0.05,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds'
	})
	Animation = AutoCollect:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the pickup animation'
	})
	Collectables = AutoCollect:CreateTextList({
		Name = 'Collectables',
		Default = {
			'alchemist_ingedients',
			'alchemy_crystal',
			'crystalheart_seed',
			'forest_environment_plant',
			'jailor_soul',
			'murder_coin',
			'shadow_coin',
			'soulvine_seed',
			'spirit_gardener_energy',
			'spirit_gardener_seeds',
			'tearbloom_seed'
		},
		Darker = true,
		Tooltip = 'Collectable tags to pick up, stars and hidden metal have their own modules'
	})
end)

run(function()
	local AutoCounter
	local Range
	local Limit
	local AutoSwitch = {}
	
	AutoCounter = vape.Categories.Utility:CreateModule({
		Name = 'AutoCounterTNT',
		Function = function(callback)
			if callback then
				local tnts, placed = {}, {}
				AutoCounter:Clean(workspace.ChildAdded:Connect(function(v)
					if v.Name == 'tnt' then
						table.insert(tnts, v)
						v.Destroying:Once(function()
							local index = table.find(tnts, v)
							if index then
								table.remove(tnts, index)
							end
						end)
					end
				end))
				repeat
					for i, v in placed do
						if v <= tick() then
							placed[i] = nil
						end
					end
					if entitylib.isAlive then
						local item
						if Limit.Enabled then
							item = store.hand.tool and store.hand.tool.Name == 'tnt' and store.hand.tool or nil
						else
							local held = getItem('tnt')
							item = held and held.tool or nil
						end
	
						if item then
							local localPosition = entitylib.character.RootPart.Position
							for _, v in tnts do
								local roundedPos = Vector3.new(math.round(v.Position.X), math.round(v.Position.Y), math.round(v.Position.Z))
								if v.AssemblyLinearVelocity.Y >= 0 and not placed[roundedPos] and (localPosition - v.Position).Magnitude <= Range.Value then
									if not Limit.Enabled and AutoSwitch.Enabled then
										local hotbar = getHotbar(item)
										switchItem(item)
										if hotbar then
											hotbarSwitch(hotbar)
										end
									end
									placed[roundedPos] = tick() + 3
									task.spawn(bedwars.placeBlock, v.Position, item.Name)
									task.wait(0.12)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoCounter.Enabled
			end
		end,
		Tooltip = 'Automatically places tnt on opponent\'s tnt'
	})
	
	AutoCounter:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On key'},
		Default = 'Toggle'
	})
	Range = AutoCounter:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30
	})
	Limit = AutoCounter:CreateToggle({
		Name = 'Limit to item',
		Function = function(callback)
			if AutoSwitch.Object then
				AutoSwitch.Object.Visible = not callback
			end
		end
	})
	AutoSwitch = AutoCounter:CreateToggle({
		Name = 'Auto Switch',
		Function = function(callback)
			Limit.Object.Visible = not callback
		end,
		Default = true
	})
end)

run(function()
	local AutoEnchant
	local Wanted
	local Repair
	local Range
	local Delay
	
	local Research = bedwars.Handler:Get('ResearchEnchant')
	local Fix = bedwars.Handler:Get('RepairEnchantTable')
	local learned
	
	AutoEnchant = vape.Categories.Utility:CreateModule({
		Name = 'AutoEnchant',
		Function = function(callback)
			if callback then
				learned = nil
	
				repeat
					if entitylib.isAlive and not table.find(Wanted.ListEnabled, learned) then
						local localPosition = entitylib.character.RootPart.Position
						local emeralds = getItem('emerald')
						local diamonds = getItem('diamond')
	
						for _, v in store.enchant do
							local part = v:IsA('Model') and v.PrimaryPart or v
							if not part or (localPosition - part.Position).Magnitude > Range.Value then continue end
	
							if v:HasTag('broken-enchant-table') then
								if Repair.Enabled and diamonds and diamonds.amount >= 8 then
									Fix:Fire('CallServer', v)
									break
								end
							elseif emeralds and emeralds.amount >= 2 then
								local enchant = Research:Fire('CallServer', {enchantTable = v})
								learned = typeof(enchant) == 'table' and enchant.enchantType or learned
								if learned then
									notif('AutoEnchant', `Researched {bedwars.EnchantMeta[learned] and bedwars.EnchantMeta[learned].name or learned}`, 3)
								end
								break
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoEnchant.Enabled
			end
		end,
		Tooltip = 'Rerolls the enchant table until you get an enchant you asked for'
	})
	
	Range = AutoEnchant:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoEnchant:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds',
		Tooltip = 'Spacing between rerolls, each one costs 2 emeralds'
	})
	Repair = AutoEnchant:CreateToggle({
		Name = 'Repair tables',
		Default = true,
		Tooltip = 'Fixes a broken enchant table for 8 diamonds before rerolling'
	})
	Wanted = AutoEnchant:CreateTextList({
		Name = 'Enchants',
		Default = {'critical_strike', 'execute', 'soul_reaver'},
		Darker = true,
		Tooltip = 'Stops rerolling once one of these is researched'
	})
end)

run(function()
	local AutoHonor
	local Delay
	
	local Honored = {}
	local function honor()
		if #Honored > 1 then return end
		local list, team = table.clone(entitylib.List), lplr:GetAttribute('Team')
		table.sort(list, function(a, b)
			return a.Player:GetAttribute('Team') == team and b.Player:GetAttribute('Team') ~= team
		end)
		for _, v in list do
			if #Honored > 1 then break end
			if not table.find(Honored, v.Player) then
				bedwars.HonorController:honorPlayer(v.Player.UserId)
				table.insert(Honored, v.Player)
				task.wait(Delay.Value)
			end
		end
	end
	
	AutoHonor = vape.Categories.Utility:CreateModule({
		Name = 'AutoHonor',
		Function = function(callback)
			if callback then
				AutoHonor:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and #bedwars.Store:getState().Party.members <= 0 and store.matchState ~= 2 then
						honor()
					end
				end))
				AutoHonor:Clean(vapeEvents.MatchEndEvent.Event:Connect(honor))
			end
		end,
		Tooltip = 'Automatically honor your teammates'
	})
	
	Delay = AutoHonor:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.1
	})
end)

run(function()
	local AutoMiner
	local Delay
	local Animation
	local Range
	
	local Legit = getFunctionRange(bedwars.MinerController.setupMinerPrompts) or 0
	
	AutoMiner = vape.Categories.Utility:CreateModule({
		Name = 'AutoMiner',
		Function = function(callback)
			if callback then
				local petrified = collection('petrified-player', AutoMiner)
				local cooldown = 0
	
				repeat
					if entitylib.isAlive and tick() - cooldown >= math.max(Delay.Value, 0.25) then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in petrified do
							local root = v:IsA('Model') and v.PrimaryPart or v
							local petrifyId = v:GetAttribute('PetrifyId')
							if root and petrifyId and (localPosition - root.Position).Magnitude <= Range.Value then
								if Animation.Enabled then
									bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.MINER_MINE_STONE)
								end
	
								task.delay(Delay.Value, function()
									if AutoMiner.Enabled and v.Parent then
										bedwars.Handler:Get('DestroyPetrifiedPlayer'):Fire('SendToServer', {
											petrifyId = petrifyId
										})
									end
								end)
								cooldown = tick()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoMiner.Enabled
			end
		end,
		Tooltip = 'Automatically mines petrified players within range'
	})
	
	Range = AutoMiner:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoMiner:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoMiner:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
	Animation = AutoMiner:CreateToggle({
		Name = 'Animation',
		Default = true
	})
end)

run(function()
	local AutoPearl
	local Mode
	local Legit
	local Back
	local Check
	local LandCheck
	local BackDelay
	local Limit
	local Distance
	local MinHealth
	local Cooldown
	local lastThrow = 0
	local inflight
	
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	
	local function firePearl(pos, spot, item)
		local hotbar, old = getHotbar(item.tool), store.hand
		lastThrow = tick() + Cooldown.Value
	
		switchItem(item.tool)
		if Legit.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end
	
		local meta = bedwars.ProjectileMeta.telepearl
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
		local landed = false
	
		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			local id = httpService:GenerateGUID(true)
			local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, id, dir, {drawDurationSeconds = 1})
			inflight = projectile
	
			bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
				item.tool,
				'telepearl',
				'telepearl',
				pos,
				pos,
				dir,
				id,
				{
					drawDurationSeconds = 1,
					shotId = httpService:GenerateGUID(false)
				},
				workspace:GetServerTimeNow() - 0.045
			):andThen(function(res)
				if res then
					res.Parent = replicatedStorage
				end
			end)
	
			task.spawn(function()
				local timeout = tick() + 10
				repeat
					task.wait()
				until not AutoPearl.Enabled or not projectile or not projectile.Parent or tick() >= timeout
				landed = true
			end)
		else
			landed = true
		end
	
		if Back.Enabled and LandCheck.Enabled then
			repeat
				task.wait()
			until landed or not AutoPearl.Enabled
		end
	
		if Back.Enabled and old and old.tool then
			task.wait(BackDelay:GetRandomValue())
			switchItem(old.tool)
			if Legit.Enabled and getHotbar(old.tool) then
				hotbarSwitch(getHotbar(old.tool))
			end
		end
	end
	
	local function findNearGround(origin)
		for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
			for i = 1, 24 do
				local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), rayCheck)
				if ray then
					return ray.Position
				end
			end
		end
	
		return nil
	end
	
	local function predictLanding(origin, velocity)
		local gravity = bedwars.ProjectileMeta.telepearl.gravitationalAcceleration or 196.2
		local position = origin
	
		for _ = 1, 240 do
			local nextvelocity = velocity - Vector3.new(0, gravity * 0.05, 0)
			local nextposition = position + (nextvelocity * 0.05)
			local ray = workspace:Raycast(position, nextposition - position, rayCheck)
			if ray then
				return ray.Position
			end
	
			if nextposition.Y < -150 then
				return nil
			end
	
			position, velocity = nextposition, nextvelocity
		end
	
		return nil
	end
	
	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			if callback then
				local launched = bedwars.SyncEvents.ProjectileLaunched:connect(function(event)
					if Mode.Value ~= 'Aggro' or event.projectileType ~= 'telepearl' then return end
					if typeof(event.origin) ~= 'Vector3' or typeof(event.launchVelocity) ~= 'Vector3' then return end
					if not entitylib.isAlive or event.shooter == entitylib.character.Character then return end
	
					local shooter
					for _, v in entitylib.List do
						if v.Character == event.shooter then
							shooter = v.Targetable and v.RootPart
							break
						end
					end
					if not shooter or not store.map then return end
	
					rayCheck.FilterDescendantsInstances = {store.map}
					rayCheck.CollisionGroup = entitylib.character.RootPart.CollisionGroup
					if tick() < lastThrow then return end
					if Check.Enabled and inflight and inflight.Parent then return end
					if MinHealth.Value > 0 and entitylib.character.Health < MinHealth.Value then return end
					if Limit.Enabled and not (store.hand.tool and store.hand.tool.Name == 'telepearl') then return end
					local item = getItem('telepearl')
					if not item then return end
	
					local landing = predictLanding(event.origin, event.launchVelocity)
					if not landing then return end
	
					local root = entitylib.character.RootPart
					if (landing - root.Position).Magnitude > Distance.Value then return end
					if (landing - root.Position).Magnitude < (shooter.Position - root.Position).Magnitude then return end
	
					firePearl(root.Position, landing, item)
				end)
	
				AutoPearl:Clean(function()
					launched:Destroy()
				end)
	
				local check, lasty
				repeat
					if Mode.Value == 'Clutch' and store.map then
						rayCheck.FilterDescendantsInstances = {store.map}
						rayCheck.CollisionGroup = entitylib.isAlive and entitylib.character.RootPart.CollisionGroup or ''
	
						local item
						if entitylib.isAlive and tick() >= lastThrow and not (Check.Enabled and inflight and inflight.Parent) and not (MinHealth.Value > 0 and entitylib.character.Health < MinHealth.Value) and not (Limit.Enabled and not (store.hand.tool and store.hand.tool.Name == 'telepearl')) then
							item = getItem('telepearl')
						end
	
						local root = entitylib.isAlive and entitylib.character.RootPart
						if root and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lasty = root.CFrame
						end
	
						if item and root and root.AssemblyLinearVelocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
								if ground then
									firePearl(root.Position, ground, item)
								end
							end
						else
							check = false
						end
					end
	
					task.wait(0.1)
				until not AutoPearl.Enabled
			else
				inflight = nil
			end
		end,
		Tooltip = 'Clutch throws a pearl onto nearby ground when you fall\nAggro throws one at where an enemy pearl is about to land'
	})
	
	Mode = AutoPearl:CreateDropdown({
		Name = 'Mode',
		List = {'Clutch', 'Aggro'},
		Function = function(value)
			if Distance then
				Distance.Object.Visible = value == 'Aggro'
			end
		end,
		Tooltip = 'Clutch saves you from a void fall, Aggro follows an enemy pearl'
	})
	Legit = AutoPearl:CreateToggle({
		Name = 'Legit Switch',
		Tooltip = 'Visualizes the switching clientside',
		Default = true
	})
	Back = AutoPearl:CreateToggle({
		Name = 'Switch back',
		Function = function(callback)
			if BackDelay then
				BackDelay.Object.Visible = callback
			end
			if LandCheck then
				LandCheck.Object.Visible = callback
			end
		end,
		Default = true,
		Tooltip = 'Switches back to the last slot before pearl'
	})
	LandCheck = AutoPearl:CreateToggle({
		Name = 'Only after landed',
		Tooltip = 'Only switches back after your pearl landed',
		Darker = true
	})
	Check = AutoPearl:CreateToggle({
		Name = 'Pearl check',
		Default = true,
		Tooltip = 'Doesn\'t throw a pearl if ur already pearling'
	})
	BackDelay = AutoPearl:CreateTwoSlider({
		Name = 'Switch Back Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Distance = AutoPearl:CreateSlider({
		Name = 'Distance limit',
		Min = 10,
		Max = 300,
		Default = 150,
		Suffix = 'studs',
		Tooltip = 'How far an enemy pearl can land before Aggro ignores it'
	})
	MinHealth = AutoPearl:CreateSlider({
		Name = 'Min health',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Never throws below this health, 0 disables the check'
	})
	Cooldown = AutoPearl:CreateSlider({
		Name = 'Cooldown',
		Min = 0,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = 'seconds',
		Tooltip = 'Minimum gap between two throws'
	})
	Limit = AutoPearl:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only throws pearl when holding a pearl'
	})
end)

run(function()
	local AutoPlay
	local Random
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then
						table.insert(listofmodes, i)
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and #bedwars.Store:getState().Party.members <= 0 and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
	
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)

run(function()
	local AutoShoot
	local Targets
	local Check
	local Projectiles
	local UseSophia
	local UseWhim
	local UseNazar
	local FireRate
	local SwitchDelay
	
	local FireDelays = {}
	
	local function getEntity()
		local selfpos = entitylib.character.RootPart.Position
		local plrs = entitylib.AllPosition({
			Origin = selfpos,
			Part = 'RootPart',
			Range = 22,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		})
		if #plrs > 0 then
			for _, v in plrs do
				local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
				local delta = (v.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)
				local angle = localfacing.Magnitude > 0 and delta.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(delta.Unit), -1, 1)) or 0
				if angle > (math.rad(120) / 2) then continue end
				return v
			end
		end
		return nil
	end
	
	AutoShoot = vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 then
						local oldtool, oldhotbar = store.hand.tool, store.inventory.hotbarSlot
						for _, v in getProjectiles(Projectiles.ListEnabled, UseSophia.Enabled, UseWhim.Enabled, UseNazar.Enabled) do
							local item, ammo, projectile, itemMeta = unpack(v)
							if (FireDelays[item.itemType] or 0) < tick() then
								local ent = getEntity()
								if not Check.Enabled or ent then
									local hotbar = getHotbar(item.tool)
									switchItem(item.tool)
									if hotbar then
										hotbarSwitch(hotbar)
									end
	
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local origin = entitylib.character.RootPart.Position
									local calc = ent and prediction.SolveTrajectory(origin, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true) or (not ent and (origin + gameCamera.CFrame.LookVector * 100))
									if calc then
										local shootPosition = (CFrame.new(origin, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
										local aim = ent and prediction.SolveTrajectory(shootPosition, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true) or calc
										local dir, id = CFrame.lookAt(shootPosition, aim).LookVector, httpService:GenerateGUID(true)
										bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
											item.tool,
											ammo,
											projectile,
											shootPosition,
											origin,
											dir * projSpeed,
											id,
											{
												drawDurationSeconds = 1,
												shotId = httpService:GenerateGUID(false),
											},
											workspace:GetServerTimeNow() - 0.045
										):andThen(function(res)
											if res then
												res.Parent = replicatedStorage
											end
										end)
										if ent then
											prediction.trackShot(ent.RootPart)
										end
										FireDelays[item.itemType] = tick() + (itemMeta.fireDelaySec + FireRate:GetRandomValue())
										task.wait(SwitchDelay.Value)
									end
								end
							end
						end
						if oldtool then
							switchItem(oldtool)
						end
						hotbarSwitch(oldhotbar)
					end
					task.wait(0.1)
				until not AutoShoot.Enabled
			end
		end,
		Tooltip = 'Automatically crossbow macro\'s'
	})
	
	Targets = AutoShoot:CreateTargets({Players = true})
	Check = AutoShoot:CreateToggle({
		Name = 'Target check',
		Function = function(callback)
			if Targets.Object then
				Targets.Object.Visible = callback
			end
		end,
		Default = true
	})
	Projectiles = AutoShoot:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	UseSophia = AutoShoot:CreateToggle({
		Name = 'Use sophia',
		Tooltip = 'Also shoots sophia\'s frost staff, swapping it out of mist mode on its own'
	})
	UseWhim = AutoShoot:CreateToggle({
		Name = 'Use whim',
		Tooltip = 'Also casts whim\'s magic book, follows whatever element you have cycled'
	})
	UseNazar = AutoShoot:CreateToggle({
		Name = 'Use nazar',
		Tooltip = 'Also shoots nazar\'s life bow, crossbow and headhunter'
	})
	FireRate = AutoShoot:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoShoot:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	local Presets = {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat
				task.wait()
				custommsg = tab[math.random(1, #tab)]
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if textChatService:CanUserChatAsync(lplr.UserId) then
				textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
			else
				textChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets[name] or Presets['So close'])
			end
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
	
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then
							sendMessage('Win', nil, 'yall garbage')
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
	
	task.spawn(pcall, function()
		for _, v in textChatService:GetPresetsAsync().categoryGroups do
			for _, v in v.categories do
				for _, v in v.messages do
					Presets[v.value] = v.presetId
				end
			end
		end
	end)
end)

run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, v in {'iron', 'diamond', 'emerald', 'gold'} do
									v = getItem(v)
									if v then
										v = bedwars.Handler:Get('DropItem'):Fire('CallServer', {
											v = v.tool,
											amount = v.amount
										})
	
										if v then
											v:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
							end
						end
					end
	
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
end)

run(function()
	local DeviceSpoofer
	local Device
	local oldDevice, old
	
	DeviceSpoofer = vape.Categories.Utility:CreateModule({
		Name = 'DeviceSpoofer',
		Function = function(callback)
			if callback then
				oldDevice, old = bedwars.UserInputController:getUserInputType(), bedwars.UserInputController.getUserInputType
				bedwars.UserInputController.getUserInputType = function()
					return Device.Value:upper()
				end
				bedwars.Handler:Get('SendUserInputType'):Fire('SendToServer', {userInputType = Device.Value:upper()})
			else
				bedwars.UserInputController.getUserInputType = old
				bedwars.Handler:Get('SendUserInputType'):Fire('SendToServer', {userInputType = oldDevice})
				old = nil
			end
		end,
		Tooltip = 'Spoofs the device you show up as to the server',
		ExtraText = function()
			return Device.Value
		end
	})
	
	Device = DeviceSpoofer:CreateDropdown({
		Name = 'Device',
		List = {'Mobile', 'PC', 'Gamepad'},
		Function = function(val)
			if DeviceSpoofer.Enabled then
				bedwars.Handler:Get('SendUserInputType'):Fire('SendToServer', {userInputType = val:upper()})
			end
		end
	})
end)

run(function()
	local KnockbackDelay
	local Chance
	local AirDelay
	local GroundDelay
	local TargetCheck
	
	local old, rand
	local function apply(type, env, ...)
		local root, mass, dir, knockback = ...
		knockback = knockback and table.clone(knockback) or {}
		knockback[type] = env[type] and knockback[type] or 0
		return old(root, mass, dir, knockback, select(5, ...))
	end
	
	KnockbackDelay = vape.Categories.Utility:CreateModule({
		Name = 'KnockbackDelay',
		Function = function(callback)
			if callback then
				old, rand = bedwars.KnockbackUtil.applyKnockback, Random.new()
				bedwars.KnockbackUtil.applyKnockback = function(...)
					if rand:NextNumber(0, 100) > Chance.Value then
						return old(...)
					end
	
					local root, mass, dir, knockback = ...
					if not TargetCheck.Enabled or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
					}) then
						local env = {}
						task.delay(AirDelay:GetRandomValue() / 1000, apply, 'horizontal', env, root, mass, dir, knockback, select(5, ...))
						task.delay(GroundDelay:GetRandomValue() / 1000, apply, 'vertical', env, root, mass, dir, knockback, select(5, ...))
						return
					end
					return old(...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old or bedwars.KnockbackUtil.applyKnockback
			end
		end,
		Tooltip = 'Delays incoming knockback packets'
	})
	
	Chance = KnockbackDelay:CreateSlider({
		Name = 'Chance',
		Min = 1,
		Max = 100,
		Suffix = '%',
		Default = 40
	})
	AirDelay = KnockbackDelay:CreateTwoSlider({
		Name = 'Air delay',
		Min = 0,
		Max = 500,
		DefaultMin = 50,
		DefaultMax = 200
	})
	GroundDelay = KnockbackDelay:CreateTwoSlider({
		Name = 'Ground delay',
		Min = 0,
		Max = 500,
		DefaultMin = 50,
		DefaultMax = 200
	})
	TargetCheck = KnockbackDelay:CreateToggle({Name = 'Target check'})
end)

run(function()
	local LeaveParty; LeaveParty = vape.Categories.Utility:CreateModule({
		Name = 'LeaveParty',
		Function = function(callback)
			if callback then
				bedwars.PartyController:leaveParty()
				LeaveParty:Toggle()
			end
		end
	})
end)

run(function()
	local MemoryFixer
	local Sync
	local Interval
	local Notify
	local signals = {'Heartbeat', 'PostSimulation', 'PreAnimation', 'PreRender', 'PreSimulation', 'RenderStepped', 'Stepped'}
	
	local function clean()
		if not getconnections or not getfunctionhash or not isexecutorclosure then
			return 0
		end
	
		local removed, seen = 0, {}
		for _, v in signals do
			for _, v2 in getconnections(runService[v]) do
				if v2.Function and not v2.ForeignState and isexecutorclosure(v2.Function) then
					local hash = v..getfunctionhash(v2.Function)
					if seen[hash] then
						v2:Disconnect()
						removed += 1
					else
						seen[hash] = true
					end
				end
			end
		end
	
		if Sync.Enabled then
			for _, v in bedwars.SyncEvents do
				if typeof(v) == 'table' and typeof(v.entries) == 'table' then
					table.clear(seen)
					for i2, v2 in v.entries do
						local callback = v2.callbackInfo and v2.callbackInfo.callback
						if callback and isexecutorclosure(callback) then
							local hash = getfunctionhash(callback)
							if seen[hash] then
								v.entries[i2] = nil
								v.isSorted = false
								removed += 1
							else
								seen[hash] = true
							end
						end
					end
				end
			end
		end
	
		return removed
	end
	
	MemoryFixer = vape.Categories.Utility:CreateModule({
		Name = 'MemoryFixer',
		Function = function(callback)
			if callback then
				task.spawn(function()
					repeat
						local removed = clean()
						if Notify.Enabled and removed > 0 then
							notif('MemoryFixer', `Dropped {removed} leftover connection{removed == 1 and '' or 's'}`, 5)
						end
						task.wait(Interval.Value)
					until not MemoryFixer.Enabled
				end)
			end
		end,
		Tooltip = 'Drops the duplicate loops and listeners an older injection left connected'
	})
	
	Sync = MemoryFixer:CreateToggle({
		Name = 'Sync events',
		Default = true,
		Tooltip = 'Also prunes duplicate bedwars sync event listeners, the ones that survive a reinject'
	})
	Interval = MemoryFixer:CreateSlider({
		Name = 'Interval',
		Min = 5,
		Max = 300,
		Default = 30,
		Suffix = 'seconds'
	})
	Notify = MemoryFixer:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Tells you how many it dropped'
	})
	MemoryFixer:CreateButton({
		Name = 'Clean now',
		Function = function()
			local removed = clean()
			notif('MemoryFixer', `Dropped {removed} leftover connection{removed == 1 and '' or 's'}`, 5)
		end
	})
end)

run(function()
	local MissileTP
	
	MissileTP = vape.Categories.Utility:CreateModule({
		Name = 'MissileTP',
		Function = function(callback)
			if callback then
				MissileTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('guided_missile') and plr then
					local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
					if projectile then
						local projectilemodel = projectile.model
						if not projectilemodel.PrimaryPart then
							projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
						end
	
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Name = 'AntiGravity'
						bodyforce.Parent = projectilemodel.PrimaryPart
	
						repeat
							projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
							task.wait(0.1)
						until not projectile.model or not projectile.model.Parent
					else
						notif('MissileTP', 'Missile on cooldown.', 3)
					end
				end
			end
		end,
		Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
	})
end)

run(function()
	local PhaseMine
	
	local old = setmetatable({}, {__mode = 'k'})
	local watching = setmetatable({}, {__mode = 'k'})
	
	local function setIgnored(part)
		if part:IsA('BasePart') and not old[part] then
			old[part] = true
			bedwars.QueryUtil:setQueryIgnored(part, true)
		end
	end
	
	local function Added(char)
		for _, v in char:QueryDescendants('BasePart') do
			setIgnored(v)
		end
	
		if not watching[char] then
			watching[char] = char.ChildAdded:Connect(setIgnored)
		end
	end
	
	PhaseMine = vape.Categories.Utility:CreateModule({
		Name = 'PhaseMine',
		Function = function(callback)
			if callback then
				PhaseMine:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if ent.Player then
						task.delay(1, Added, ent.Character)
					end
				end))
	
				for _, v in entitylib.List do
					if v.Player and v.Player ~= lplr and v.Character then
						Added(v.Character)
					end
				end
			else
				for _, v in watching do
					v:Disconnect()
				end
				table.clear(watching)
	
				for i in old do
					if i.Parent then
						bedwars.QueryUtil:setQueryIgnored(i, false)
					end
				end
				table.clear(old)
			end
		end,
		Tooltip = 'Allows you to mine through opponents'
	})
end)

run(function()
	local PickupRange
	local Range
	local Network
	local Lower
	local Picked = {}
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in items do
							if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 or table.find(Picked, v) then continue end
							if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0))
							end
	
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
								local InsertPosition = #Picked + 1
								table.insert(Picked, InsertPosition, v)
								task.spawn(function()
									bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {
										itemDrop = v
									}):andThen(function(suc)
										table.remove(Picked, InsertPosition)
										if suc and bedwars.SoundList then
											bedwars.AudioManager:playAudio(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.AudioManager:playAudio(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})
	
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Network = PickupRange:CreateToggle({
		Name = 'Network TP',
		Default = true
	})
	Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)

run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local FillColor
	local OutlineColor
	local adjacent, lastpos, label, visualBlock = {}, Vector3.zero
	local visualTween, visualPos
	local visualSpeed = 0.1
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	getgenv().nearCorner = nearCorner
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	getgenv().blockProximity = blockProximity
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	getgenv().checkAdjacent = checkAdjacent
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local wool, amount = getWool()
			if wool then
				return wool, amount
			else
				for _, v in store.inventory.inventory.items do
					if bedwars.ItemMeta[v.itemType].block then
						return v.itemType, v.amount
					end
				end
			end
		end
	
		return nil, 0
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()
	
						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end
	
						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end
	
						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 38, root.AssemblyLinearVelocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								if visualBlock and currentpos then
									local visual = bedwars.BlockController:getBlockPosition(currentpos) * 3
									if visualPos ~= visual then
										if visualTween then
											visualTween:Cancel()
											visualTween = nil
										end
	
										if visualBlock.Parent == gameCamera then
											visualTween = tweenService:Create(visualBlock, TweenInfo.new(visualSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(visual)})
											visualTween:Play()
										else
											visualBlock.CFrame = CFrame.new(visual)
											visualBlock.Parent = gameCamera
										end
										visualPos = visual
									end
								end
	
								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
									if blockpos then
										task.delay(0, bedwars.placeBlock, blockpos, wool, false)
									end
								end
								lastpos = currentpos
							end
						end
					end
					task.wait(0.03)
				until not Scaffold.Enabled
				if visualTween then
					visualTween:Cancel()
					visualTween = nil
				end
				if visualBlock then
					visualBlock.Parent = nil
				end
				visualPos = nil
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Scaffold:CreateToggle({
		Name = 'Visual',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			if callback then
				visualBlock = Instance.new('Part')
				visualBlock.Size = Vector3.new(3, 3, 3)
				visualBlock.Anchored = true
				visualBlock.CanCollide = false
				visualBlock.CanQuery = false
				visualBlock.CanTouch = false
				visualBlock.CastShadow = false
				visualBlock.Transparency = 1
				local selection = Instance.new('SelectionBox')
				selection.Adornee = visualBlock
				selection.LineThickness = 0.04
				selection.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				selection.Transparency = 1 - OutlineColor.Opacity
				selection.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				selection.SurfaceTransparency = 1 - FillColor.Opacity
				selection.Parent = visualBlock
				bedwars.QueryUtil:setQueryIgnored(visualBlock, true)
			else
				if visualTween then
					visualTween:Cancel()
					visualTween = nil
				end
				if visualBlock then
					visualBlock.Parent = nil
				end
				visualPos = nil
				visualBlock:Destroy()
				visualBlock = nil
			end
		end,
		Tooltip = 'Renders an overlay on the block about to be placed'
	})
	FillColor = Scaffold:CreateColorSlider({
		Name = 'Fill Color',
		DefaultSat = 0,
		DefaultOpacity = 0.4,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.SurfaceColor3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.SurfaceTransparency = 1 - opacity
			end
		end
	})
	OutlineColor = Scaffold:CreateColorSlider({
		Name = 'Outline Color',
		DefaultValue = 0,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.Color3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.Transparency = 1 - opacity
			end
		end
	})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)

run(function()
	local SetEmote
	local Emote
	local track
	
	local list, old = {}, {}
	for i, v in bedwars.EmoteMeta do
		if i ~= bedwars.EmoteType.NONE and v.name and not old[v.name] then
			old[v.name] = i
			table.insert(list, v.name)
		end
	end
	table.sort(list)
	
	local function cancelEmote()
		if entitylib.isAlive then
			if track then
				track:Stop()
				track:Destroy()
				track = nil
			end
			if lplr.Character:GetAttribute('PlayingEmote') then
				lplr.Character:SetAttribute('PlayingEmote', nil)
			end
		end
	end
	
	SetEmote = vape.Categories.Utility:CreateModule({
		Name = 'SetEmote',
		Function = function(callback)
			if callback then
				SetEmote:Toggle()
				if entitylib.isAlive then
					local emoteType = old[Emote.Value]
					local meta = bedwars.EmoteMeta[emoteType]
					if meta then
						lplr.Character:SetAttribute('PlayingEmote', emoteType)
						local playBeginSounds = bedwars.EmoteController.createEmoteBeginAudioPlayers or bedwars.EmoteController.playEmoteBeginSounds
						if playBeginSounds then
							playBeginSounds(bedwars.EmoteController, emoteType, lplr)
						end
						local animation = meta.animation
						if not animation and meta.emoteDisplayType then
							local display = bedwars.EmoteDisplayMeta[meta.emoteDisplayType]
							animation = display and display.animation
						end
						if animation and not noAutoPlayAnimation then
							track = lplr.Character.Humanoid:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(animation.type))
							track.Looped = animation.looped or false
							track:Play(nil, nil, animation.speed or 1)
						end
						if not meta.animation then
							local gui = Instance.new('BillboardGui')
							gui.Size = UDim2.fromScale(6, 2.5)
							gui.StudsOffset = Vector3.new(0, 2, 0)
							gui.AlwaysOnTop = true
							gui.Adornee = lplr.Character.Head
	
							local image = Instance.new('ImageLabel')
							image.AnchorPoint = Vector2.new(0.5, 1)
							image.Position = UDim2.fromScale(0.5, 1)
							image.Size = UDim2.fromScale(0, 0)
							image.Image = meta.image
							image.BackgroundTransparency = 1
							image.ImageTransparency = 1
							image.ScaleType = Enum.ScaleType.Fit
							image.Parent = gui
	
							gui.Parent = lplr.Character.Head
							tweenService:Create(image, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ImageTransparency = 0
							}):Play()
						end
						if meta.allowMovement then
							task.delay(6, cancelEmote)
						else
							lplr.Character.Humanoid:GetPropertyChangedSignal('MoveDirection'):Once(cancelEmote)
						end
					end
				end
			end
		end,
		Tooltip = 'Plays selected emote clientsidedly'
	})
	
	Emote = SetEmote:CreateDropdown({
		Name = 'Emote',
		List = list,
		Default = 'nightmare'
	})
end)

run(function()
	local ShopQuickBuy
	local HoldDelay
	local CPS
	
	local holding = false
	local clickThread
	
	local function getShopId()
		if not entitylib.isAlive then return nil end
		local localPosition = entitylib.character.RootPart.Position
		local id
		for _, v in store.shop do
			if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
				id = v.Id
			end
		end
		return id
	end
	
	local function getHoveredItem()
		local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
		for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
			local obj = v
			while obj and obj ~= lplr.PlayerGui do
				local itemType = obj.Name:match('^(.+)_ShopItemCard$')
				if itemType then
					return itemType
				end
				obj = obj.Parent
			end
		end
	end
	
	local function startClicking(itemType)
		if clickThread then
			task.cancel(clickThread)
		end
		clickThread = task.spawn(function()
			repeat
				local shopId = bedwars.AppController:isAppOpen('BedwarsItemShopApp') and store.shopLoaded and getShopId()
				if shopId and bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] == nil then
					local item = bedwars.Shop.getShopItem(itemType, lplr, {shopId = shopId})
					local currency = item and getItem(item.currency)
					local buyable = item and not (item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '')) and not item.lockedByForge and not item.disabled and (currency and currency.amount or 0) >= item.price
					if buyable and item.require and item.require.teamUpgrade and (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
						buyable = false
					end
	
					if buyable then
						bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
							shopItem = item,
							shopId = shopId
						}):andThen(function(suc)
							if not suc then return end
							bedwars.AudioManager:playAudio(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
							bedwars.Store:dispatch({
								type = 'BedwarsAddItemPurchased',
								itemType = itemType
							})
							if item.tiered then
								bedwars.BedwarsShopController.alreadyPurchasedMap[itemType] = true
							end
						end)
					end
				end
				task.wait(1 / CPS.Value)
			until not holding
			clickThread = nil
		end)
	end
	
	ShopQuickBuy = vape.Categories.Utility:CreateModule({
		Name = 'ShopClicker',
		Function = function(callback)
			if callback then
				ShopQuickBuy:Clean(inputService.InputBegan:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					if not bedwars.AppController:isAppOpen('BedwarsItemShopApp') then return end
	
					local itemType = getHoveredItem()
					if not itemType then return end
	
					holding = true
					task.delay(HoldDelay.Value, function()
						if holding and getHoveredItem() == itemType then
							startClicking(itemType)
						end
					end)
				end))
	
				ShopQuickBuy:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						holding = false
					end
				end))
			else
				holding = false
				if clickThread then
					task.cancel(clickThread)
					clickThread = nil
				end
			end
		end,
		Tooltip = 'Hold on a shop item to rapidly buy it.'
	})
	
	HoldDelay = ShopQuickBuy:CreateSlider({
		Name = 'Hold Delay',
		Min = 0,
		Max = 1,
		Default = 0.15,
		Decimal = 20,
		Suffix = 'seconds'
	})
	CPS = ShopQuickBuy:CreateSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		Default = 20,
		Darker = true
	})
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local joined, rejoins, jointimes = {}, {}, {}
	local counts = {Spectate = 0, Mod = 0, Impossible = 0}
	local flagcolors = {Spectate = 'rgb(236,129,43)', Mod = 'rgb(250,50,56)', Impossible = 'rgb(180,90,250)'}
	local entries = {}
	local window, infolabel, expanded
	
	local function refreshViewer()
		if not window then return end
	
		local showlist = expanded and #entries > 0
		local stuff = {'<b>StaffDetector</b>', '<font size="4"> </font>'}
		for _, v in {'Spectate', 'Mod', 'Impossible'} do
			table.insert(stuff, `<font color="{flagcolors[v]}">{v}: {counts[v]}</font>`)
		end
	
		if showlist then
			table.insert(stuff, '<font size="4"> </font>')
			for i, v in entries do
				if i > 8 then break end
				table.insert(stuff, `{v.Name} <font color="{flagcolors[v.Category]}">{v.Reason}</font>`)
			end
		end
	
		infolabel.Text = table.concat(stuff, '\n')
		local size = getfontbounds(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
		local title = getfontbounds('StaffDetector', infolabel.TextSize, Font.new(infolabel.FontFace.Family, Enum.FontWeight.Bold))
		window.Size = UDim2.fromOffset(math.max(size.X, title.X) + 16, size.Y + (showlist and -8 or 4))
	end
	
	local function staffFunction(plr, checktype)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
		local category = checktype == 'impossible_join' and 'Impossible' or checktype == 'spectator' and 'Spectate' or 'Mod'
		counts[category] += 1
		table.insert(entries, 1, {Name = plr.Name, Reason = checktype, Category = category})
		refreshViewer()
	
		if Party.Enabled and not checktype:find('clan') then
			bedwars.PartyController:leaveParty()
		end
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Requeue' then
			bedwars.QueueController:joinQueue(store.queueType)
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (table.find(safe, i) or v.Category == 'Render') then
					if v.Enabled then
						v:Toggle()
					end
					v:SetBind('')
				end
			end
		end
	end
	
	local function noteSpectator(plr, reason)
		notif('StaffDetector', `Spectator {plr.Name} joined {reason}`, 20, 'warning')
		counts.Spectate += 1
		table.insert(entries, 1, {Name = plr.Name, Reason = 'spectator', Category = 'Spectate'})
		refreshViewer()
	end
	
	local function checkJoin(plr, connection)
		if plr:GetAttribute('Team') or not plr:GetAttribute('Spectator') or store.matchState ~= 1 or bedwars.Store:getState().Game.customMatch or (tick() - (jointimes[plr.UserId] or 0)) > 20 then return end
	
		connection:Disconnect()
		task.wait(5)
		if (not StaffDetector.Enabled) or plr.Parent ~= playersService or plr:GetAttribute('Team') or not plr:GetAttribute('Spectator') then return end
	
		if rejoins[plr.UserId] then
			noteSpectator(plr, 'back after leaving')
			return
		end
	
		if plr.FollowUserId ~= 0 and joined[plr.FollowUserId] then
			noteSpectator(plr, `following {joined[plr.FollowUserId]}`)
			return
		end
	
		local suc, pages = pcall(playersService.GetFriendsAsync, playersService, plr.UserId)
		if not suc then return end
	
		local friend, finished = nil, pages.IsFinished
		for _ = 1, 6 do
			for _, v in pages:GetCurrentPage() do
				if joined[v.Id] then
					friend = joined[v.Id]
					break
				end
			end
			if friend or finished then break end
			if not pcall(pages.AdvanceToNextPageAsync, pages) then return end
			finished = pages.IsFinished
		end
	
		if friend then
			noteSpectator(plr, `from {friend}`)
		elseif finished then
			staffFunction(plr, 'impossible_join')
			return true
		end
	end
	
	local function playerAdded(plr)
		if joined[plr.UserId] then
			rejoins[plr.UserId] = true
		end
		joined[plr.UserId] = plr.Name
		local teleported = plr:GetAttribute('LastTeleported')
		jointimes[plr.UserId] = teleported and (tick() - math.min(workspace:GetServerTimeNow() - teleported, 60)) or tick()
		if plr == lplr then return end
	
		if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
			staffFunction(plr, 'blacklisted_user')
		else
			local suc, res = pcall(function()
				return plr:GetRankInGroup(5774246)
			end)
			if not suc then
				notif('StaffDetector', res, 30, 'alert')
			end
	
			if (suc and res or 0) >= 100 then
				staffFunction(plr, 'staff_role')
			else
				local connection
				connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
					checkJoin(plr, connection)
				end)
				StaffDetector:Clean(connection)
				if checkJoin(plr, connection) then
					return
				end
	
				if not plr:GetAttribute('ClanTag') then
					plr:GetAttributeChangedSignal('ClanTag'):Wait()
				end
	
				if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
					connection:Disconnect()
					staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
				end
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			else
				table.clear(joined)
				table.clear(rejoins)
				table.clear(jointimes)
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})
	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
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
	StaffDetector:CreateToggle({
		Name = 'Viewer',
		Function = function(callback)
			if callback and not window then
				window = Instance.new('TextButton')
				window.Name = 'StaffDetectorViewer'
				window.Position = UDim2.fromOffset(12, 120)
				window.BackgroundColor3 = Color3.new()
				window.BackgroundTransparency = 0.5
				window.Text = ''
				window.AutoButtonColor = false
				window.Parent = vape.gui.ScaledGui
				addBlur(window)
				local corner = Instance.new('UICorner')
				corner.CornerRadius = UDim.new(0, 5)
				corner.Parent = window
	
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
				infolabel.Parent = window
	
				window.MouseButton1Click:Connect(function()
					expanded = not expanded
					refreshViewer()
				end)
			end
	
			if window then
				window.Visible = callback
				refreshViewer()
			end
		end,
		Tooltip = 'Shows a panel with detection counts, click it to list who tripped them'
	})
	task.spawn(function()
		repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
		if vape.Loaded and not StaffDetector.Enabled then
			StaffDetector:Toggle()
		end
	end)
end)

run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'Drops the reports the game makes you send when you walk into a trap'
	})
	
	TrapSnap = TrapDisabler:CreateToggle({
		Name = 'Snap traps',
		Default = true,
		Tooltip = 'Stops trapper snap traps from marking you'
	})
	TrapMine = TrapDisabler:CreateToggle({
		Name = 'Landmines',
		Default = true,
		Tooltip = 'Stops invisible landmines from detonating on you'
	})
	TrapTeleport = TrapDisabler:CreateToggle({
		Name = 'Teleport blocks',
		Tooltip = 'Stops teleport blocks from moving you'
	})
	TrapPortal = TrapDisabler:CreateToggle({
		Name = 'Void portals',
		Tooltip = 'Stops void portals from moving you, this also blocks your own'
	})
end)

run(function()
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					v:Disconnect()
				end
	
				for _, v in getconnections(runService.Heartbeat) do
					if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), 'AfkInfo') then
						v:Disconnect()
					end
				end
	
				bedwars.Handler:Get('AfkInfo'):Fire('SendToServer', {
					afk = false
				})
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)

run(function()
	local AutoBedDefense
	local Repair
	local Upgrade
	local Range
	local Reserve
	
	local holding, held
	
	AutoBedDefense = vape.Categories.World:CreateModule({
		Name = 'AutoBedDefense',
		Function = function(callback)
			if callback then
				holding, held = nil, false
	
				AutoBedDefense:Clean(proximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
					if prompt == holding then
						held = true
					end
				end))
	
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local iron = getItem('iron')
						iron = (iron and iron.amount or 0) - Reserve.Value
						local target
	
						for _, v in collectionService:GetTagged('UpgradeBedDefense') do
							local part = v.Parent
							if not part or not part:IsA('BasePart') or (localPosition - part.Position).Magnitude > Range.Value then continue end
	
							local tier = bedwars.BedDefenseMeta[(v:GetAttribute('DefenseLevel') or 0) + 2]
							local missing = v:GetAttribute('MissingBlocks') or 0
							if missing > 0 and Repair.Enabled and iron >= bedwars.NoBuildUtil.REPAIR_COST then
								target = v
								break
							elseif missing <= 0 and Upgrade.Enabled and tier and iron >= tier.cost.amount then
								target = v
								break
							end
						end
	
						if target ~= holding then
							if holding then
								holding:InputHoldEnd()
							end
							holding, held = target, false
							if target then
								target:InputHoldBegin()
							end
						elseif target and not held then
							target:InputHoldBegin()
						end
					end
					task.wait(0.2)
				until not AutoBedDefense.Enabled
			else
				if holding then
					holding:InputHoldEnd()
				end
				holding, held = nil, false
			end
		end,
		Tooltip = 'Holds the bed defense prompt for you so your bed stays repaired and upgraded'
	})
	
	Range = AutoBedDefense:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 14,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Reserve = AutoBedDefense:CreateSlider({
		Name = 'Reserve',
		Min = 0,
		Max = 64,
		Default = 0,
		Suffix = 'iron',
		Tooltip = 'Iron to leave alone for the shop'
	})
	Repair = AutoBedDefense:CreateToggle({
		Name = 'Repair',
		Default = true,
		Tooltip = 'Replaces the layers an enemy broke, 5 iron each'
	})
	Upgrade = AutoBedDefense:CreateToggle({
		Name = 'Upgrade',
		Default = true,
		Tooltip = 'Buys the next defense tier once the defense is whole again'
	})
end)

run(function()
	local AutoTool
	local Mode
	local Delay = {}
	local SwitchBack
	local old, event
	local looking, deadline, previous, switching = nil, 0, nil, false
	
	local function getToolSlot(block)
		if not block or block:GetAttribute('NoBreak') or block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then return end
	
		local meta = bedwars.ItemMeta[block.Name]
		local tool = meta and meta.block and store.tools[meta.block.breakType]
		if not tool or (store.hand and store.hand.tool == tool.tool) then return end
	
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == tool.itemType then
				return i - 1
			end
		end
		return
	end
	
	local function switchTo(slot)
		if switching then return end
	
		switching = true
		task.spawn(function()
			hotbarSwitch(slot)
			switching = false
		end)
	end
	
	AutoTool = vape.Categories.World:CreateModule({
		Name = 'AutoTool',
		Function = function(callback)
			if callback then
				looking, deadline, previous, switching = nil, 0, nil, false
	
				event = Instance.new('BindableEvent')
				AutoTool:Clean(event)
				AutoTool:Clean(event.Event:Connect(function()
					contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
				end))
	
				AutoTool:Clean(runService.Heartbeat:Connect(function()
					if Mode.Value ~= 'Look' or not entitylib.isAlive then return end
	
					local held = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
					if not (held and held.breakBlock) then
						looking, previous = nil, nil
						return
					end
	
					local placer = store.blockPlacer or (bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer)
					local selector = placer and placer.clientManager and placer.clientManager:getBlockSelector()
					local info = selector and selector:getMouseInfo(1)
					local block = info and info.target and info.target.blockInstance or nil
					if not block then
						looking = nil
						if SwitchBack.Enabled and previous then
							switchTo(previous)
							previous = nil
						end
						return
					end
	
					if block ~= looking then
						looking, deadline = block, tick() + Delay:GetRandomValue()
						return
					end
					if tick() < deadline then return end
	
					local slot = getToolSlot(block)
					if slot then
						previous = previous or (store.hand.tool and getHotbar(store.hand.tool) or nil)
						switchTo(slot)
					end
				end))
	
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					if Mode.Value == 'Break' then
						local info = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						local slot = getToolSlot(info and info.target and info.target.blockInstance or nil)
						if slot then
							task.spawn(function()
								if hotbarSwitch(slot) and inputService:IsMouseButtonPressed(0) then
									event:Fire()
								end
							end)
						end
					end
					return old(self, maid, raycastparams, ...)
				end
			else
				looking, previous = nil, nil
				if old then
					bedwars.BlockBreaker.hitBlock = old
					old = nil
				end
			end
		end,
		Tooltip = 'Automatically selects the correct tool'
	})
	
	Mode = AutoTool:CreateDropdown({
		Name = 'Mode',
		List = {'Look', 'Break'},
		Function = function(value)
			if Delay.Object then
				Delay.Object.Visible = value == 'Look'
				SwitchBack.Object.Visible = value == 'Look'
			end
		end,
		Default = 'Break',
		Tooltip = 'Look swaps while you are still aiming at the block, Break swaps on the first hit like it used to'
	})
	Delay = AutoTool:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		DefaultMin = 0.06,
		DefaultMax = 0.16,
		Darker = true,
		Suffix = 'seconds',
		Tooltip = 'How long you have to be looking at the block before it swaps'
	})
	SwitchBack = AutoTool:CreateToggle({
		Name = 'Switch back',
		Darker = true,
		Tooltip = 'Puts the item you were holding back once you look away'
	})
end)

run(function()
	local BedAssist
	local AimMode
	local Speed
	local Range
	local Shake
	local Mode
	local Limit
	
	local started = 0
	local aimfuncs = {
		Simple = function(localcframe, pos, fps)
			local rng = Random.new()
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, pos + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), Speed.Value * fps), Speed.Value
		end,
		Adaptive = function(localcframe, pos, fps)
			local prog, rng = (math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1) < 0.5 and 4 * math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1) * math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1) * math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1) or 1 - math.pow(-2 * math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1) + 2, 3) / 2), Random.new()
			local speed = Speed.Value * prog
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, pos + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end
	}
	
	local function getBestPosition(block)
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos = math.huge, nil
		local mag = 9e9
	
		local positions = (handler and handler:getContainedPositions(block) or {block.Position / 3})
		for _, v in positions do
			local dpos, dcost = calculatePath(block, v * 3)
			local dmag = dpos and (entitylib.character.RootPart.Position - dpos).Magnitude
	
			if dpos then
				if dcost < cost or (dcost == cost and dmag < mag) then
					cost, pos, mag = dcost, dpos, dmag
				end
			end
		end
	
		if pos and (entitylib.character.RootPart.Position - pos).Magnitude <= Range.Value then
			return pos
		end
		return nil
	end
	
	BedAssist = vape.Categories.World:CreateModule({
		Name = 'BedAssist',
		Function = function(call)
			if call then
				repeat
					task.wait()
				until store.matchState ~= 0 or not BedAssist.Enabled
				if not BedAssist.Enabled then
					return
				end
	
				local beds = collection('bed', BedAssist, function(tab, obj)
					task.delay(0, function()
						if not obj:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then
							table.insert(tab, obj)
						end
					end)
				end)
				local rng = Random.new()
				local lastbed = nil
	
				BedAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in beds do
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if lastbed ~= v then
									started = tick()
								end
								lastbed = v
	
								local pos = getBestPosition(v)
								if pos then
									local pred, speed = aimfuncs[AimMode.Value](gameCamera.CFrame, pos, dt)
	
									if Mode.Value == 'Mouse' then
										pos += Vector3.new(
											(rng:NextNumber() - 0.5) * Shake.Value * 0.1,
											(rng:NextNumber() - 0.5) * Shake.Value * 0.1,
											(rng:NextNumber() - 0.5) * Shake.Value * 0.1
										)
										local campos, vis = gameCamera:WorldToViewportPoint(pos)
										if vis then
											local vec2 = (Vector2.new(campos.X, campos.Y) - inputService:GetMouseLocation()) * (speed * dt)
											mousemoverel(vec2.X, vec2.Y)
										end
									else
										gameCamera.CFrame = pred
									end
								end
								break
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Smoothly aims towards a bed close to your mouse'
	})
	
	local list = {'Camera'}
	if inputService.MouseEnabled and mousemoverel then
		table.insert(list, 'Mouse')
	end
	AimMode = BedAssist:CreateDropdown({
		Name = 'Mode',
		List = {'Simple', 'Adaptive'},
		Default = 'Simple'
	})
	Mode = BedAssist:CreateDropdown({
		Name = 'Aim mode',
		List = list,
		Default = 'Camera'
	})
	Speed = BedAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 7
	})
	Range = BedAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Shake = BedAssist:CreateSlider({
		Name = 'Shake',
		Min = 1,
		Max = 100,
		Default = 3
	})
	Limit = BedAssist:CreateToggle({Name = 'Limit to item', Default = true})
end)

run(function()
	local BedPatcher
	local Mode
	local Whitelist
	local PlaceRange
	local Radius
	local Wool
	local Switch
	local NoAnimation
	local Limit
	local layout, adjacent = {}, {}
	local placeanimation = bedwars.BlockController:getAnimationController():getAssetId(0)
	local placing, old = false
	
	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(adjacent, Vector3.FromNormalId(v) * 3)
	end
	
	local function getBedNear()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude < (PlaceRange.Value + Radius.Value) and v:GetAttribute('Team'..(lplr:GetAttribute('Team') or -1)..'NoBreak') then
				return v
			end
		end
		return nil
	end
	
	local function getBlock(itemType)
		if Limit.Enabled then
			local hand = store.hand.toolType == 'block' and store.hand.tool
			if hand and (not Wool.Enabled or hand.Name:find('wool')) and table.find(Whitelist.ListEnabled, hand.Name:find('wool') and 'wool' or hand.Name) then
				return hand.Name, hand
			end
			return nil
		end
	
		local best, health
		for _, v in store.inventory.inventory.items do
			local block = bedwars.ItemMeta[v.itemType].block
			if not block or (Wool.Enabled and not v.itemType:find('wool')) then continue end
			if not table.find(Whitelist.ListEnabled, v.itemType:find('wool') and 'wool' or v.itemType) then continue end
			if v.itemType == itemType then
				return v.itemType, v.tool
			end
			if not health or (block.health or 0) > health then
				best, health = v, block.health or 0
			end
		end
		return best and best.itemType or nil, best and best.tool or nil
	end
	
	local function scanBed(bed)
		table.clear(layout)
		for _, v in store.blocks do
			if not v:HasTag('bed') and (v.Position - bed.Position).Magnitude <= Radius.Value then
				layout[v.Position] = v.Name
			end
		end
	
		local holes = {}
		for i, v in layout do
			for _, v2 in adjacent do
				local cell = i + v2
				if layout[cell] or holes[cell] or getPlacedBlock(cell) then continue end
	
				local walls = 0
				for _, v in adjacent do
					if layout[cell + v] then
						walls += 1
					end
				end
	
				if walls >= 4 then
					holes[cell] = v
				end
			end
		end
	
		for i, v in holes do
			layout[i] = v
		end
	end
	
	BedPatcher = vape.Categories.World:CreateModule({
		Name = 'BedPatcher',
		Function = function(callback)
			if callback then
				local bed
				old = bedwars.AnimationUtil.playAnimation
				bedwars.AnimationUtil.playAnimation = function(self, plr, assetId, config)
					if placing and NoAnimation.Enabled and assetId == placeanimation then return end
					return old(self, plr, assetId, config)
				end
	
				BedPatcher:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(function(v)
					if bed and not v:HasTag('bed') and (v.Position - bed.Position).Magnitude <= Radius.Value then
						layout[v.Position] = v.Name
					end
				end))
	
				BedPatcher:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(blockTable)
					local plr = blockTable.player
					if plr and (plr == lplr or plr:GetAttribute('Team') == lplr:GetAttribute('Team')) then
						layout[blockTable.blockRef.blockPosition * 3] = nil
					end
				end))
	
				repeat
					local found = getBedNear()
					if found ~= bed then
						bed = found
						if bed then
							scanBed(bed)
						else
							table.clear(layout)
						end
					end
	
					if bed and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local holes = {}
	
						for i, v in layout do
							if (localPosition - i).Magnitude <= PlaceRange.Value and not getPlacedBlock(i) then
								table.insert(holes, {i, v})
							end
						end
	
						table.sort(holes, function(a, b)
							return (a[1] - bed.Position).Magnitude < (b[1] - bed.Position).Magnitude
						end)
	
						for _, v in holes do
							local pos, itemType = unpack(v)
							if getPlacedBlock(pos) then continue end
	
							local item, tool = getBlock(itemType)
							if not item then break end
	
							if Switch.Enabled and getHotbar(tool) and hotbarSwitch(getHotbar(tool)) then
								task.wait()
							end
	
							placing = true
							bedwars.placeBlock(pos, item)
							placing = false
							task.wait(1 / bedwars.SharedConstants.BLOCK_PLACE_CPS)
						end
					elseif not bed and Mode.Value == 'On Key' then
						notif('BedPatcher', 'Unable to locate bed', 5)
						BedPatcher:Toggle()
						break
					end
	
					task.wait(0.5)
					if Mode.Value == 'On Key' then
						BedPatcher:Toggle()
						break
					end
				until not BedPatcher.Enabled
			else
				bedwars.AnimationUtil.playAnimation = old
				placing = false
			end
		end,
		Tooltip = 'Puts back the blocks an enemy broke out of your bed defense.'
	})
	
	Mode = BedPatcher:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'},
		Default = 'Toggle'
	})
	Whitelist = BedPatcher:CreateTextList({
		Name = 'Whitelist',
		Default = {'wool', 'obsidian'}
	})
	PlaceRange = BedPatcher:CreateSlider({
		Name = 'Place Range',
		Min = 1,
		Max = 60,
		Default = 15
	})
	Radius = BedPatcher:CreateSlider({
		Name = 'Defense Radius',
		Min = 3,
		Max = 30,
		Default = 15,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far out from the bed still counts as your defense'
	})
	Wool = BedPatcher:CreateToggle({Name = 'Wool only', Tooltip = 'Only uses wools to patch.'})
	Switch = BedPatcher:CreateToggle({Name = 'Auto Switch'})
	NoAnimation = BedPatcher:CreateToggle({
		Name = 'No Animation',
		Tooltip = 'Hides the arm swing every patched block would otherwise play'
	})
	Limit = BedPatcher:CreateToggle({Name = 'Limit to item'})
end)

run(function()
	local BedPlates
	local Background
	local Color
	local LayerCounter
	local LayerColor
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function getBlockLayerHealth(block)
		local meta = bedwars.ItemMeta[block]
		return meta and meta.block and meta.block.health or 0
	end
	
	local function scanSide(self, start, tab)
		for _, v in sides do
			local layers = {}
			for i = 1, 15 do
				local block = getPlacedBlock(start + (v * i))
				if not block or block == self or block.Name == 'bed' then
					break
				end
				if not block:GetAttribute('NoBreak') then
					layers[block.Name] = (layers[block.Name] or 0) + 1
				end
			end
	
			for i, v in layers do
				tab[i] = math.max(tab[i] or 0, v)
			end
		end
	end
	
	local function refreshAdornee(v)
		for _, v in v.Frame:GetChildren() do
			if v:IsA('ImageLabel') and v.Name ~= 'Blur' then
				v:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local layers = {}
		local alreadygot = {}
		scanSide(v.Adornee, start, layers)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), layers)
		for i, v in layers do
			table.insert(alreadygot, {i, v})
		end
		table.sort(alreadygot, function(a, b)
			local healthA, healthB = getBlockLayerHealth(a[1]), getBlockLayerHealth(b[1])
			return healthA == healthB and a[1] < b[1] or healthA > healthB
		end)
		v.Enabled = #alreadygot > 0
	
		for _, v2 in alreadygot do
			local block, amount = v2[1], v2[2]
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
			if amount > 1 and (not LayerCounter or LayerCounter.Enabled) then
				local amounttext = Instance.new('TextLabel')
				amounttext.Name = 'Amount'
				amounttext.Size = UDim2.fromScale(1, 1)
				amounttext.BackgroundTransparency = 1
				amounttext.Text = tostring(amount)
				amounttext.TextColor3 = (LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.new(1, 1, 1))
				amounttext.TextSize = 16
				amounttext.TextStrokeTransparency = 0.3
				amounttext.Font = Enum.Font.Arial
				amounttext.Parent = blockimage
			end
		end
	end
	
	local function Added(v)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	BedPlates = vape.Categories.World:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('bed') do
					task.spawn(Added, v)
				end
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays blocks over the bed'
	})
	
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color and Color.Object then
				Color.Object.Visible = callback
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
	LayerCounter = BedPlates:CreateToggle({
		Name = 'Layer Counter',
		Function = function(callback)
			if LayerColor and LayerColor.Object then
				LayerColor.Object.Visible = callback
			end
			for _, v in Reference do
				refreshAdornee(v)
			end
		end,
		Default = true
	})
	LayerColor = BedPlates:CreateColorSlider({
		Name = 'Counter Text Color',
		Function = function()
			local textColor = (LayerColor and Color3.fromHSV(LayerColor.Hue, LayerColor.Sat, LayerColor.Value) or Color3.new(1, 1, 1))
			for _, v in Reference do
				for _, v in v.Frame:GetDescendants() do
					if v:IsA('TextLabel') and v.Name == 'Amount' then
						v.TextColor3 = textColor
					end
				end
			end
		end,
		DefaultSat = 0,
		DefaultValue = 1
	})
end)

run(function()
	local BedProtector
	local PlaceRange
	local Blacklist
	local Wool
	local Mode
	local Smart
	local Switch
	
	local function getBedNear()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude < 14 and v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then
				return v
			end
		end
		return nil
	end
	
	local function getBlocks()
		local blocks = {}
		for _, v in store.inventory.inventory.items do
			local block = bedwars.ItemMeta[v.itemType].block
			if block and (Wool.Enabled and v.itemType:find('wool') or not Wool.Enabled and not table.find(Blacklist.ListEnabled, v.itemType:find('wool') and 'wool' or v.itemType)) then
				table.insert(blocks, {v.itemType, block.health, v.tool})
			end
		end
		if #blocks > 1 then
			table.sort(blocks, function(a, b)
				return a[2] > b[2]
			end)
		end
		return blocks
	end
	
	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end
	
	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				repeat
					local bed = getBedNear()
					if bed then
						for i2, v2 in getBlocks() do
							local switch, old = Switch.Enabled, store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
							local hotbar = nil
	
							if switch then
								hotbar = getHotbar(v2[3])
							end
	
							for _, v in getPyramid(i2, 3) do
								if not BedProtector.Enabled then
									break
								end
								v = (bed.CFrame * CFrame.new(v)).Position
								if getPlacedBlock(v) then
									continue
								end
								if (entitylib.character.RootPart.Position - v).Magnitude > PlaceRange.Value then
									continue
								end
								if hotbar and hotbarSwitch(hotbar) then
									task.wait()
								end
								task.spawn(bedwars.placeBlock, v, v2[1], false)
								task.wait(0.1)
							end
	
							if switch and old and hotbarSwitch(old) then
								task.wait()
							end
						end
					else
						if Mode.Value == 'On Key' then
							notif('BedProtector', 'Unable to locate bed', 5)
							BedProtector:Toggle()
						end
					end
					task.wait(0.5)
					if Mode.Value == 'On Key' then
						BedProtector:Toggle()
						break
					end
				until not BedProtector.Enabled
			end
		end,
		Tooltip = 'Automatically places strong blocks around the bed.'
	})
	
	Mode = BedProtector:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'},
		Function = function(val)
			if Smart then
				Smart.Object.Visible = val == 'Toggle'
			end
		end,
		Default = 'Toggle'
	})
	Blacklist = BedProtector:CreateTextList({
		Name = 'Blacklist',
		Default = {'siege_tnt', 'tnt'}
	})
	PlaceRange = BedProtector:CreateSlider({
		Name = 'Place Range',
		Min = 1,
		Max = 30,
		Default = 15
	})
	Wool = BedProtector:CreateToggle({Name = 'Wool only', Tooltip = 'Only uses wools to bed defend.'})
	Switch = BedProtector:CreateToggle({Name = 'Auto Switch'})
	Smart = BedProtector:CreateToggle({Name = 'Smart', Default = true})
end)

run(function()
	local BlockIn
	local Mode
	local Priority
	local Return
	local Switch
	local Wool
	local Blacklist
	
	local scan = 30
	local dirs = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1)
	}
	local priorities = {
		['Lowest cost'] = function(a, b)
			return a[2] < b[2]
		end,
		['Hardest'] = function(a, b)
			return a[2] > b[2]
		end
	}
	
	local function getOrigin()
		local pos = entitylib.character.RootPart.Position
		local ray = entitylib.Raycast(pos, Vector3.new(0, -scan, 0), store.airRay)
		return roundPos(ray and Vector3.new(pos.X, ray.Position.Y + 1.5, pos.Z) or pos)
	end
	
	local function getBedNear()
		local localPosition = entitylib.character.RootPart.Position
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude >= 14 or v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then continue end
	
			local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v.Name)
			local cells = handler and handler:getContainedPositions(v) or {v.Position / 3}
			local occupied = {}
			for _, v2 in cells do
				occupied[v2 * 3] = true
			end
	
			local defended = true
			for _, v2 in cells do
				for i2 = 1, #sides do
					local pos = (v2 * 3) + sides[i2]
					if not occupied[pos] and not getPlacedBlock(pos) then
						defended = false
						break
					end
				end
				if not defended then break end
			end
	
			if defended then
				return v
			end
		end
		return nil
	end
	
	local function buildCol(getBlock, root, dir, height)
		local out = {}
		local col = root + dir * 3
		local topY = root.Y + 2 * 3
		local sup
		local y = topY
		while y >= (topY - scan) do
			local pos = Vector3.new(col.X, y, col.Z)
			if getBlock(Vector3.new(math.floor(pos.X / 3 + 0.5) * 3, math.floor(pos.Y / 3 + 0.5) * 3, math.floor(pos.Z / 3 + 0.5) * 3)) then
				sup = y
				break
			end
			y -= 3
		end
		local sy
		if sup then
			sy = sup + 3
		else
			sy = topY - (height - 1) * 3
		end
		local y = sy
		while y <= topY do
			table.insert(out, Vector3.new(dir.X * 3, y - root.Y, dir.Z * 3))
			y += 3
		end
		return out
	end
	
	local function getPattern(root, getBlock)
		local pattern = {}
		local cols = {}
		for _, v in ipairs(dirs) do
			local out = buildCol(getBlock, root, v, 2)
			table.insert(cols, {v = v, out = out, cost = #out})
		end
		table.sort(cols, function(a, b)
			return a.cost < b.cost
		end)
		local capY = 0
		for _, v in ipairs(cols) do
			if #v.out > 0 then
				local top = v.out[#v.out]
				if top.Y > capY then
					capY = top.Y
				end
			end
		end
		for _, v in ipairs(cols[1].out) do
			table.insert(pattern, v)
		end
		table.insert(pattern, Vector3.new(0, capY, 0))
		for i = 2, #cols do
			for _, v in ipairs(cols[i].out) do
				if v.Y ~= capY then
					table.insert(pattern, v)
				end
			end
		end
		return pattern
	end
	
	local function placePattern(origin, patterns, limit)
		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or 0
		local placed = 0
		local blocks = {}
		for _, v in store.inventory.inventory.items do
			local block = bedwars.ItemMeta[v.itemType].block
			if block and (Wool.Enabled and v.itemType:find('wool') or not Wool.Enabled and not table.find(Blacklist.ListEnabled, v.itemType:find('wool') and 'wool' or v.itemType)) then
				table.insert(blocks, {v.itemType, block.health, v.tool})
			end
		end
		if #blocks > 1 then
			table.sort(blocks, priorities[Priority.Value])
		end
	
		for _, v in blocks do
			if placed >= limit then break end
			local block = getHotbar(v[3])
			if not block and Switch.Enabled then
				continue
			end
	
			if Switch.Enabled then
				hotbarSwitch(block)
			end
			for _, v2 in patterns do
				if placed >= limit or not entitylib.isAlive then break end
				if getPlacedBlock(origin + v2) then continue end
				repeat task.wait() until not entitylib.isAlive or (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= (1 / 12)
				if not entitylib.isAlive then break end
	
				local root = entitylib.character.RootPart
				if math.abs(root.Position.X - origin.X) > 0.5 or math.abs(root.Position.Z - origin.Z) > 0.5 then
					root.CFrame = CFrame.new(origin.X, root.Position.Y, origin.Z) * (root.CFrame - root.Position)
				end
				bedwars.placeBlock(origin + v2, v[1], true)
				placed += 1
			end
		end
		if Return.Enabled and Switch.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end
	end
	
	BlockIn = vape.Categories.World:CreateModule({
		Name = 'Block-In',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and (Mode.Value == 'On bind' or getBedNear()) then
						local early = false
						repeat
							task.wait()
							if entitylib.isAlive and not early then
								local origin = getOrigin()
								local drop = entitylib.character.RootPart.Position.Y - origin.Y
								early = drop >= 6 and drop <= 24
								if early then
									placePattern(origin, getPattern(origin, getPlacedBlock), 3)
								end
							end
						until not BlockIn.Enabled or not entitylib.isAlive or entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
	
						if entitylib.isAlive then
							local origin = getOrigin()
							placePattern(origin, getPattern(origin, getPlacedBlock), math.huge)
						end
					end
	
					if Mode.Value == 'On bind' then
						BlockIn:Toggle()
						break
					end
					task.wait(0.5)
				until not BlockIn.Enabled
			end
		end,
		Tooltip = 'Automatically blocks you in by building walls around you'
	})
	
	Mode = BlockIn:CreateDropdown({
		Name = 'Mode',
		List = {'On bind', 'When near'},
		Default = 'On bind',
		Tooltip = 'On bind blocks you in once per keypress, When near keeps you blocked in while you are on an enemy bed'
	})
	Priority = BlockIn:CreateDropdown({
		Name = 'Block priority',
		List = {'Lowest cost', 'Hardest'},
		Default = 'Lowest cost'
	})
	Switch = BlockIn:CreateToggle({Name = 'Switch', Default = true})
	Return = BlockIn:CreateToggle({Name = 'Return to last slot', Default = true})
	Wool = BlockIn:CreateToggle({Name = 'Wool only'})
	Blacklist = BlockIn:CreateTextList({
		Name = 'Blacklist',
		Default = {'cannon', 'siege_tnt', 'tnt'}
	})
end)

run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local Legit
	local Visualize
	local FillColor
	local OutlineColor
	local Animate
	local Speed
	local Delays = {}
	local Boxes = {}
	local Tweens = {}
	local BoxTargets = {}
	
	local function updateBoxes(targets)
		for i2, v2 in Boxes do
			local chest = targets and targets[i2]
			if chest ~= BoxTargets[i2] then
				if Tweens[i2] then
					Tweens[i2]:Cancel()
					Tweens[i2] = nil
				end
	
				if not chest then
					v2.Parent = nil
				elseif Animate.Enabled and v2.Parent == gameCamera then
					Tweens[i2] = tweenService:Create(v2, TweenInfo.new(Speed.Value, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = chest.CFrame})
					Tweens[i2]:Play()
				else
					v2.CFrame = chest.CFrame
					v2.Parent = gameCamera
				end
				BoxTargets[i2] = chest
			end
	
			if chest then
				v2.SelectionBox.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				v2.SelectionBox.Transparency = 1 - OutlineColor.Opacity
				v2.SelectionBox.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				v2.SelectionBox.SurfaceTransparency = 1 - FillColor.Opacity
			end
		end
	end
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + 0.2
			local observed = lplr.Character and lplr.Character:FindFirstChild('ObservedChestFolder')
			observed = observed and observed.Value or nil
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
					if Legit.Enabled then
						task.wait(0.2)
					end
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(observed)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				local function getChestPart(folder)
					for _, v in chests do
						local value = v:FindFirstChild('ChestFolderValue')
						if value and value.Value == folder then
							return v
						end
					end
					return nil
				end
	
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						local targets = {}
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController:isAppOpen('ChestApp') then
									local observed = lplr.Character:FindFirstChild('ObservedChestFolder')
									lootChest(observed)
									targets[1] = observed and observed.Value and getChestPart(observed.Value) or nil
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								local closest = math.huge
								for _, v in chests do
									local magnitude = (localPosition - v.Position).Magnitude
									if magnitude <= Range.Value then
										lootChest(v:FindFirstChild('ChestFolderValue'))
										if magnitude < closest then
											closest, targets[1] = magnitude, v
										end
									end
								end
							end
						end
	
						updateBoxes(targets)
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			else
				updateBoxes(nil)
			end
		end,
		Tooltip = 'Grabs items from near chests.'
	})
	
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Visualize = ChestSteal:CreateToggle({
		Name = 'Visualize',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			Animate.Object.Visible = callback
			Speed.Object.Visible = callback
			if callback then
				local part = Instance.new('Part')
				part.Size = Vector3.new(3, 3, 3)
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Transparency = 1
				local selection = Instance.new('SelectionBox')
				selection.Adornee = part
				selection.LineThickness = 0.04
				selection.Parent = part
				bedwars.QueryUtil:setQueryIgnored(part, true)
				Boxes[1] = part
			else
				updateBoxes(nil)
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
				table.clear(Tweens)
				table.clear(BoxTargets)
			end
		end,
		Tooltip = 'Draws a box around the closest chest being looted'
	})
	FillColor = ChestSteal:CreateColorSlider({
		Name = 'Fill Color',
		DefaultSat = 0,
		DefaultOpacity = 0.25,
		Darker = true,
		Visible = false
	})
	OutlineColor = ChestSteal:CreateColorSlider({
		Name = 'Outline Color',
		DefaultSat = 0,
		Darker = true,
		Visible = false
	})
	Animate = ChestSteal:CreateToggle({
		Name = 'Animate',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Glides the box onto the next chest instead of snapping to it'
	})
	Speed = ChestSteal:CreateSlider({
		Name = 'Animation time',
		Min = 0.01,
		Max = 0.5,
		Default = 0.08,
		Decimal = 100,
		Suffix = 's',
		Darker = true,
		Visible = false
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Legit = ChestSteal:CreateToggle(({Name = 'Legit mode'}))
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
end)

run(function()
	local FastPlace
	local CPS
	
	FastPlace = vape.Categories.World:CreateModule({
		Name = 'FastPlace',
		Function = function(callback)
			bedwars.SharedConstants.BLOCK_PLACE_CPS = callback and CPS.Value or 12
		end,
		Tooltip = 'Changes the block place delay'
	})
	
	CPS = FastPlace:CreateSlider({
		Name = 'Cps',
		Min = 1,
		Max = 100,
		Function = function(val)
			if FastPlace.Enabled then
				bedwars.SharedConstants.BLOCK_PLACE_CPS = val
			end
		end,
		Default = 13
	})
	FastPlace:CreateButton({
		Name = 'Reset to bedwars cps',
		Function = function()
			CPS:SetValue(12)
		end
	})
end)

run(function()
	local Nuker
	local Mode
	local ClosestBreak
	local Range
	local BreakSpeed
	local UpdateRate
	local Custom
	local Bed
	local Tesla
	local Hive
	local LuckyBlock
	local IronOre
	local Effect
	local CustomHealth = {}
	local Animation = {}
	local SelfBreak
	local LimitItem
	local Wallcheck
	local ViewAngle
	local AutoTool
	local customlist, parts = {}, {}
	local mouse = cloneref(lplr:GetMouse())
	local mouseParams = RaycastParams.new()
	mouseParams.FilterType = Enum.RaycastFilterType.Exclude
	local mouseOrigin, mouseDirection, mouseHit = Vector3.zero, Vector3.zero
	
	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		xpcall(function()
			if block:GetAttribute('NoHealthbar') then return end
			if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
				if self.healthbarPart then
					bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)
				end
				self.maid:DoCleaning()
				self.healthbarBlockRef = blockRef
				local roact = bedwars.Roact
				local create = roact.createElement
				local percent = math.clamp(health / maxHealth, 0, 1)
				local cleanCheck = true
				local part = Instance.new('Part')
				part.Size = Vector3.one
				part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
				part.Transparency = 1
				part.Anchored = true
				part.CanCollide = false
				part.Parent = workspace
				bedwars.QueryUtil:setQueryIgnored(part, true)
				self.healthbarPart = part
	
				local mounted = roact.mount(create('BillboardGui', {
					Size = UDim2.fromOffset(249, 102),
					StudsOffset = Vector3.new(0, 2.5, 0),
					Adornee = part,
					MaxDistance = 40,
					AlwaysOnTop = true
				}, {
					create('Frame', {
						Size = UDim2.fromOffset(160, 50),
						Position = UDim2.fromOffset(44, 32),
						BackgroundColor3 = Color3.new(),
						BackgroundTransparency = 0.5
					}, {
						create('UICorner', {CornerRadius = UDim.new(0, 5)}),
						create('ImageLabel', {
							Size = UDim2.new(1, 89, 1, 52),
							Position = UDim2.fromOffset(-48, -31),
							BackgroundTransparency = 1,
							Image = getvapeasset('catsix/assets/new/blur.png'),
							ScaleType = Enum.ScaleType.Slice,
							SliceCenter = Rect.new(52, 31, 261, 502)
						}),
						create('TextLabel', {
							Size = UDim2.fromOffset(145, 14),
							Position = UDim2.fromOffset(13, 12),
							BackgroundTransparency = 1,
							Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							TextColor3 = Color3.new(),
							TextScaled = true,
							Font = Enum.Font.Arial
						}),
						create('TextLabel', {
							Size = UDim2.fromOffset(145, 14),
							Position = UDim2.fromOffset(12, 11),
							BackgroundTransparency = 1,
							Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Top,
							TextColor3 = color.Dark(uipallet.Text, 0.16),
							TextScaled = true,
							Font = Enum.Font.Arial
						}),
						create('Frame', {
							Size = UDim2.fromOffset(138, 4),
							Position = UDim2.fromOffset(12, 32),
							BackgroundColor3 = uipallet.Main
						}, {
							create('UICorner', {CornerRadius = UDim.new(1, 0)}),
							create('Frame', {
								[roact.Ref] = self.blockHealthbar.healthbarProgressRef,
								Size = UDim2.fromScale(percent, 1),
								BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
							}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
						})
					})
				}), part)
	
				self.maid:GiveTask(function()
					cleanCheck = false
					self.healthbarBlockRef = nil
					roact.unmount(mounted)
					if self.healthbarPart then
						self.healthbarPart:Destroy()
					end
					self.healthbarPart = nil
				end)
	
				bedwars.RuntimeLib.Promise.delay(5):andThen(function()
					if cleanCheck then
						self.maid:DoCleaning()
					end
				end)
			end
	
			local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
			tweenService:Create(self.blockHealthbar.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
				Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
			}):Play()
		end, function(...)
			if shared.VapeDeveloper then
				warn(...)
			end
		end)
	end
	
	local hit = 0
	
	local function attemptBreak(tab, localPosition, route, teamcheck)
		if not tab then return end
	
		local block, closest = nil, math.huge
		for _, v in tab do
			if (v.Position - localPosition).Magnitude >= Range.Value or not bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then continue end
			if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
			if teamcheck then
				local placer = playersService:GetPlayerByUserId(v:GetAttribute('PlacedByUserId') or 0)
				if placer and placer:GetAttribute('Team') == lplr:GetAttribute('Team') then continue end
			end
			if Wallcheck.Enabled and not ClosestBreak.Enabled and ViewAngle.Value < 180 then
				local offset = v.Position - gameCamera.CFrame.Position
				if offset.Magnitude > 0 and math.deg(math.acos(math.clamp(offset.Unit:Dot(gameCamera.CFrame.LookVector), -1, 1))) > ViewAngle.Value then continue end
			end
			if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
			if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end
	
			if not ClosestBreak.Enabled or v == mouseHit then
				block = v
				break
			end
	
			local offset = v.Position - mouseOrigin
			local along = offset:Dot(mouseDirection)
			local spread = along > 0 and (offset - mouseDirection * along).Magnitude or offset.Magnitude
			if spread < closest then
				block, closest = v, spread
			end
		end
	
		if not block then return false end
	
		hit += 1
		local target, path, endpos = bedwars.breakBlock(block, Effect.Enabled, Animation.Value ~= 'No Animation' and Animation.Value or nil, CustomHealth.Enabled and customHealthbar or nil, AutoTool.Enabled, Wallcheck.Enabled, ClosestBreak.Enabled and breakmethods.Distance or breakmethods[Mode.Value], not route)
		local currentnode = target
		for _, v in parts do
			v.Position = currentnode or Vector3.zero
			if currentnode then
				v.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
			end
			currentnode = path and path[currentnode]
		end
	
		task.wait(BreakSpeed.Value)
	
		return true
	end
	
	Nuker = vape.Categories.World:CreateModule({
		Name = 'Nuker',
		ConfigName = 'Breaker',
		Function = function(callback)
			if callback then
				for _ = 1, 30 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanQuery = false
					part.CanCollide = false
					part.Transparency = 1
					part.Parent = gameCamera
					local highlight = Instance.new('BoxHandleAdornment')
					highlight.Size = Vector3.one
					highlight.AlwaysOnTop = true
					highlight.ZIndex = 1
					highlight.Transparency = 0.5
					highlight.Adornee = part
					highlight.Parent = part
					table.insert(parts, part)
				end
	
				local beds = collection('bed', Nuker)
				local teslas = collection('tesla-trap', Nuker)
				local hives = collection('beehive', Nuker)
				local luckyblock = collection('LuckyBlock', Nuker)
				local ironores = collection('iron_ore_mesh_block', Nuker)
				customlist = collection('block', Nuker, function(tab, obj)
					if table.find(Custom.ListEnabled, obj.Name) then
						table.insert(tab, obj)
					end
				end)
	
				repeat
					task.wait(1 / UpdateRate.Value)
					if not Nuker.Enabled then break end
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
	
						if ClosestBreak.Enabled then
							local ignore = {lplr.Character, gameCamera}
							for _, v in entitylib.List do
								if v.Character then
									table.insert(ignore, v.Character)
								end
							end
							mouseParams.FilterDescendantsInstances = ignore
							mouseOrigin, mouseDirection = mouse.UnitRay.Origin, mouse.UnitRay.Direction
							local ray = workspace:Raycast(mouseOrigin, mouseDirection * 999, mouseParams)
							mouseHit = ray and ray.Instance or nil
						end
	
						if attemptBreak(Bed.Enabled and beds, localPosition, true) then continue end
						if attemptBreak(Hive.Enabled and hives, localPosition, nil, true) then continue end
						if attemptBreak(Tesla.Enabled and teslas, localPosition, nil, true) then continue end
						if attemptBreak(IronOre.Enabled and ironores, localPosition) then continue end
						if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition) then continue end
						if attemptBreak(customlist, localPosition) then continue end
	
						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Nuker.Enabled
			else
				for _, v in parts do
					v:ClearAllChildren()
					v:Destroy()
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Break blocks around you automatically'
	})
	
	Mode = Nuker:CreateDropdown({
		Name = 'Break mode',
		List = {'Health', 'Distance'},
		Default = 'Health'
	})
	ClosestBreak = Nuker:CreateToggle({
		Name = 'Closest break',
		Function = function(callback)
			Mode.Object.Visible = not callback
		end,
		Tooltip = 'Ignores the break mode and always takes the block nearest your crosshair, seeing straight through players'
	})
	Range = Nuker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BreakSpeed = Nuker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	UpdateRate = Nuker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Nuker:CreateTextList({
		Name = 'Custom',
		Function = function()
			if not customlist then return end
			table.clear(customlist)
			for _, v in store.blocks do
				if table.find(Custom.ListEnabled, v.Name) then
					table.insert(customlist, v)
				end
			end
		end
	})
	Bed = Nuker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	Tesla = Nuker:CreateToggle({
		Name = 'Break Tesla',
		Default = true
	})
	Hive = Nuker:CreateToggle({
		Name = 'Break Hive',
		Default = true
	})
	LuckyBlock = Nuker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Nuker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Effect = Nuker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Nuker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Nuker:CreateDropdown({
		Name = 'Animation Mode',
		List = {'No Animation', 'Minimal', 'Full'},
		Tooltip = 'Minimal plays the tiny stub you get while macroing, Full plays the whole swing'
	})
	SelfBreak = Nuker:CreateToggle({Name = 'Self Break'})
	Wallcheck = Nuker:CreateToggle({
		Name = 'Legit mode',
		Function = function(callback)
			if ViewAngle then
				ViewAngle.Object.Visible = callback
			end
		end,
		Default = true,
		Tooltip = 'Checks for blocks inside the bed instead of directly targetting bed,\nand only breaks what you are actually looking at'
	})
	ViewAngle = Nuker:CreateSlider({
		Name = 'View angle',
		Min = 5,
		Max = 180,
		Default = 60,
		Suffix = 'degrees',
		Darker = true,
		Tooltip = 'How far off your crosshair a block can sit in legit mode, 180 breaks anything in range'
	})
	AutoTool = Nuker:CreateToggle({
		Name = 'Auto Tool',
		Tooltip = 'Visualises tool switching on ur client'
	})
	LimitItem = Nuker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
end)

run(function()
	local ArmorSwitch
	local Mode
	local Targets
	local Range
	
	ArmorSwitch = vape.Categories.Inventory:CreateModule({
		Name = 'ArmorSwitch',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Toggle' then
					repeat
						local state = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Wallcheck = Targets.Walls.Enabled
						}) and true or false
	
						for i = 0, 2 do
							if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
								bedwars.Store:dispatch({
									type = 'InventorySetArmorItem',
									item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
									armorSlot = i
								})
								vapeEvents.InventoryChanged.Event:Wait()
							end
						end
						task.wait(0.1)
					until not ArmorSwitch.Enabled
				else
					ArmorSwitch:Toggle()
					for i = 0, 2 do
						bedwars.Store:dispatch({
							type = 'InventorySetArmorItem',
							item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
							armorSlot = i
						})
						vapeEvents.InventoryChanged.Event:Wait()
					end
				end
			end
		end,
		Tooltip = 'Puts on / takes off armor when toggled for baiting.'
	})
	
	Mode = ArmorSwitch:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'}
	})
	Targets = ArmorSwitch:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = ArmorSwitch:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local BedwarsCheck
	local GUI
	local SmartCheck
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	
	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}
	
	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if (v.RootPart.Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end
	
	local function buyItem(item, currencytable)
		if not id then return end
		notif('AutoBuy', `Bought {bedwars.ItemMeta[item.itemType].displayName}`, 3)
		bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.AudioManager:playAudio(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
				bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
			end
		end)
		currencytable[item.currency] -= item.price
	end
	
	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
	
		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if v.nextTier then break end
		end
	
		if buyable then
			buyItem(buyable, currencytable)
		end
	
		return bought
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
	
				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					if (npctick - tick()) > 1 then npctick = tick() end
				end))
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
							npc = nil
						end
					end
	
					if npc and lastupgrades ~= upgrades then
						if (npctick - tick()) > 1 then npctick = tick() end
						lastupgrades = upgrades
					end
	
					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, v in Callbacks do
							for _, v2 in v do
								if v2(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						npctick = tick() + (waitcheck and 0.4 or math.huge)
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
	
				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end
	
				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades or not Upgrades.Enabled then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
	
					local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
					local bought = false
					for i2 = (currentUpgrades[i] or 0) + 1, #v.tiers do
						local tier = v.tiers[i2]
						if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
						if not canBuy({currency = 'diamond', price = tier.cost}, currencytable) then break end
	
						notif('AutoBuy', `Bought {v.name == 'Armor' and 'Protection' or v.name} {i2}`, 3)
						bedwars.Handler:Get('RequestPurchaseTeamUpgrade'):Fire('CallServerAsync', i)
						currencytable.diamond -= tier.cost
						bought = true
					end
	
					return bought
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, v in list do
				local tab = v:split('/')
				local ind = tonumber(tab[1])
				if ind then
					(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end
	
						local item = bedwars.Shop.getShopItem(tab[2], lplr)
						if item then
							local held = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWoolById(lplr:GetAttribute('Team')) or tab[2])
							held = (held and tonumber(tab[3]) - held.amount or tonumber(tab[3])) // item.amount
							if held > 0 and canBuy(item, currencytable, held) then
								for _ = 1, held do
									buyItem(item, currencytable)
								end
								return true
							end
						end
					end
				end
			end
		end
	})
end)

run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					for _ = 1, 4 do
						if bedwars.Handler:Get('ConsumeItem'):Fire('CallServer', {item = speedpotion.tool}) then break end
					end
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
					if apple then
						bedwars.Handler:Get('ConsumeItem'):Fire('CallServerAsync', {
							item = apple.tool
						})
					end
				end
			end
	
			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
					if shield then
						bedwars.Handler:Get('ConsumeItem'):Fire('CallServerAsync', {
							item = shield.tool
						})
					end
				end
			end
		end
	end
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						consumeCheck(attribute)
					end
				end))
				consumeCheck()
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%'
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
end)

run(function()
	local AutoFish
	local Show
	local Blacklist
	local Minigame
	local MinigameMode = {}
	local CompleteDelay = {}
	local Reaction = {}
	local Clicks = {}
	local Cast
	local CastDelay = {}
	local rejects = {}
	
	local old
	
	local function getCastSpot()
		local localPosition = entitylib.character.RootPart.Position
		local open
	
		for dist = 5, 17, 3 do
			for angle = 0, 330, 30 do
				local spot = localPosition + (CFrame.Angles(0, math.rad(angle), 0).LookVector * dist)
				local ray = entitylib.Raycast(spot + Vector3.new(0, 8, 0), Vector3.new(0, -26, 0), store.airRay)
				local check = ray and ray.Position or spot
				local rejected = false
				for _, v in rejects do
					if (v - check).Magnitude < 4 then
						rejected = true
						break
					end
				end
	
				if not ray then
					if not open and not rejected then
						open = spot
					end
				elseif ray.Material == Enum.Material.Water and not rejected then
					return ray.Position
				end
			end
		end
		return open
	end
	
	local function playMinigame()
		local util = bedwars.FishermanUtil
		local marker, zone
		local deadline = tick() + 3
		repeat
			for _, v in lplr.PlayerGui:GetDescendants() do
				if v.Name == 'Marker' and v.Parent and v.Parent.Name == 'Minigame' then
					local found = v.Parent:FindFirstChild('FishZone')
					if found then
						marker, zone = v, found
						break
					end
				end
			end
			if not marker then task.wait() end
		until marker or tick() > deadline
		if not marker then return end
	
		local speed, aim = util.startingMarkerIncrementSpeed, 0
		repeat
			if not marker.Parent or not zone.Parent then return end
	
			local width = marker.AbsoluteSize.X
			local center = marker.AbsolutePosition.X + (width / 2)
			local delta = ((zone.AbsolutePosition.X + (zone.AbsoluteSize.X / 2) + aim) - center) / math.max(width, 1)
			if delta > 0.2 then
				tweenService:Create(marker, TweenInfo.new(math.max(speed, util.holdMinimumMarkerIncrementSpeed), Enum.EasingStyle.Linear), {
					Position = UDim2.new(math.min(marker.Position.X.Scale + util.markerIncrementAmount, 1 - marker.Size.X.Scale), 0, 0.5, 0)
				}):Play()
				speed -= 0.01
				task.wait(0.05)
			elseif delta < -0.2 then
				tweenService:Create(marker, TweenInfo.new(util.totalDecaySpeedSec * (marker.Position.X.Scale + marker.Size.X.Scale), Enum.EasingStyle.Linear), {
					Position = UDim2.new(0, 2, 0.5, 0)
				}):Play()
				speed = util.startingMarkerIncrementSpeed
				aim = (math.random() - 0.5) * width * 0.1
				task.wait(Reaction:GetRandomValue())
			else
				local period = 1 / Clicks:GetRandomValue()
				tweenService:Create(marker, TweenInfo.new(math.max(util.startingMarkerIncrementSpeed, util.holdMinimumMarkerIncrementSpeed), Enum.EasingStyle.Linear), {
					Position = UDim2.new(math.min(marker.Position.X.Scale + util.markerIncrementAmount, 1 - marker.Size.X.Scale), 0, 0.5, 0)
				}):Play()
				task.wait(period * (0.35 + (math.random() * 0.25)))
				tweenService:Create(marker, TweenInfo.new(util.totalDecaySpeedSec * (marker.Position.X.Scale + marker.Size.X.Scale), Enum.EasingStyle.Linear), {
					Position = UDim2.new(0, 2, 0.5, 0)
				}):Play()
				speed = util.startingMarkerIncrementSpeed
				aim = (math.random() - 0.5) * width * 0.1
				task.wait(period * (0.35 + (math.random() * 0.25)))
			end
		until not AutoFish.Enabled or not Minigame.Enabled
	end
	
	AutoFish = vape.Categories.Inventory:CreateModule({
		Name = 'AutoFish',
		Function = function(callback)
			if callback then
				old = bedwars.FishingMinigameController.startMinigame
				bedwars.FishingMinigameController.startMinigame = function(...)
					if Minigame.Enabled and MinigameMode.Value == 'Instant' then
						task.wait(CompleteDelay:GetRandomValue())
						return select(3, ...)({win = true})
					end
	
					local call = (old or bedwars.FishingMinigameController.startMinigame)(...)
					if Minigame.Enabled then
						task.spawn(playMinigame)
					end
					return call
				end
	
				AutoFish:Clean(bedwars.Handler:Get('FishFound').Remote:Connect(function(data)
					local reroll = #Blacklist.ListEnabled > 0
					for _, v in data.dropData.drops do
						local amount = tonumber(v.amount) or 0
						if Show.Enabled then
							local itemDisplay = bedwars.ItemMeta[v.itemType] and bedwars.ItemMeta[v.itemType].displayName or v.itemType
							notif('AutoFish', `You can get {amount} {itemDisplay:lower()}{amount >= 2 and 's' or ''} on ur next fish`, 20, 'info')
						end
						if not table.find(Blacklist.ListEnabled, v.itemType) then
							reroll = false
						end
					end
	
					if reroll and entitylib.isAlive then
						lplr.Character.Humanoid.Jump = true
					end
				end))
				repeat
					local bait
					for _, v in workspace:GetChildren() do
						if v.Name == 'fisherman_bobber' and v:GetAttribute('ProjectileShooter') == lplr.UserId then
							bait = v
							break
						end
					end
	
					if entitylib.isAlive and Cast.Enabled and (store.hand.tool and store.hand.tool.Name == 'fishing_rod') and not bait then
						local spot = getCastSpot()
						if not spot and #rejects > 0 then
							table.clear(rejects)
							spot = getCastSpot()
						end
	
						if spot then
							task.wait(CastDelay:GetRandomValue())
							if AutoFish.Enabled then
								local item = bedwars.FishingRodController:getHandItem()
								if item and not bedwars.FishingRodController.projectileHandler and bedwars.FishingRodController:canLaunch() then
									bedwars.FishingRodController:beginHolding(item, nil, bedwars.FishingRodController.aimingMaid, false)
									task.wait()
									local handler = bedwars.FishingRodController.projectileHandler
									if handler then
										local meta = bedwars.ProjectileMeta.fisherman_bobber
										local origin = (bedwars.ProjectileController:getLaunchPosition(item.tool) or entitylib.character.RootPart.Position) + handler.fromPositionOffset
										handler.targetPoint = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0) or spot
									end
									bedwars.FishingRodController:releaseChargeInput(bedwars.FishingRodController.aimingMaid, function()
										return true
									end, nil)
								end
	
								task.wait(2.5)
								local cast
								for _, v in workspace:GetChildren() do
									if v.Name == 'fisherman_bobber' and v:GetAttribute('ProjectileShooter') == lplr.UserId then
										cast = v
										break
									end
								end
								if not cast or not cast:GetAttribute('WaitingForFish') then
									table.insert(rejects, spot)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoFish.Enabled
			else
				table.clear(rejects)
				if old then
					bedwars.FishingMinigameController.startMinigame = old
					old = nil
				end
			end
		end,
		Tooltip = 'Automatically fishes with fishing rod'
	})
	
	Blacklist = AutoFish:CreateTextList({
		Name = 'Blacklisted loot',
		Default = {'iron'},
		Tooltip = 'Jumps to cancel the catch when every item the fish drops is blacklisted'
	})
	Show = AutoFish:CreateToggle({
		Name = 'Show loot drops',
		Tooltip = 'Notifies ur next lootdrops'
	})
	Minigame = AutoFish:CreateToggle({
		Name = 'Auto Minigame',
		Function = function(callback)
			if MinigameMode.Object then
				MinigameMode.Object.Visible = callback
				CompleteDelay.Object.Visible = callback and MinigameMode.Value == 'Instant'
				Reaction.Object.Visible = callback and MinigameMode.Value == 'Legit'
				Clicks.Object.Visible = callback and MinigameMode.Value == 'Legit'
			end
		end,
		Default = true,
		Tooltip = 'Automatically completes the minigame'
	})
	MinigameMode = AutoFish:CreateDropdown({
		Name = 'Minigame mode',
		List = {'Instant', 'Legit'},
		Darker = true,
		Function = function(value)
			if CompleteDelay.Object then
				CompleteDelay.Object.Visible = Minigame.Enabled and value == 'Instant'
				Reaction.Object.Visible = Minigame.Enabled and value == 'Legit'
				Clicks.Object.Visible = Minigame.Enabled and value == 'Legit'
			end
		end,
		Tooltip = 'Instant wins the moment the minigame opens, Legit plays the bar out itself'
	})
	CompleteDelay = AutoFish:CreateTwoSlider({
		Name = 'Complete delay',
		Min = 0,
		Max = 25,
		Decimal = 5,
		DefaultMin = 0.1,
		DefaultMax = 0.9,
		Darker = true
	})
	Reaction = AutoFish:CreateTwoSlider({
		Name = 'Reaction',
		Min = 0,
		Max = 1,
		Decimal = 100,
		DefaultMin = 0.06,
		DefaultMax = 0.19,
		Darker = true,
		Visible = false,
		Tooltip = 'How long it takes to notice the fish moved away before it lets go'
	})
	Clicks = AutoFish:CreateTwoSlider({
		Name = 'Clicks',
		Min = 3,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 13,
		Darker = true,
		Visible = false,
		Suffix = 'cps',
		Tooltip = 'How fast it taps to hover the bar on the fish'
	})
	Cast = AutoFish:CreateToggle({
		Name = 'Auto Cast',
		Function = function(callback)
			if CastDelay.Object then
				CastDelay.Object.Visible = callback
			end
		end,
		Tooltip = 'Finds a spot to fish at and casts there, ignoring where ur camera looks'
	})
	CastDelay = AutoFish:CreateTwoSlider({
		Name = 'Cast delay',
		Min = 0,
		Max = 5,
		Decimal = 5,
		DefaultMin = 0.3,
		DefaultMax = 1.2,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local AutoHotbar
	local Mode
	local Clear
	local List
	local Active
	
	local function CreateWindow(self)
		local selectedslot = 1
		local window = Instance.new('Frame')
		window.Name = 'HotbarGUI'
		window.Size = UDim2.fromOffset(660, 465)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.BackgroundColor3 = uipallet.Main
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Visible = false
		window.Parent = vape.gui.ScaledGui
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.BackgroundTransparency = 1
		title.Text = 'AutoHotbar'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 40)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		addBlur(window)
		local modal = Instance.new('TextButton')
		modal.Text = ''
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Parent = window
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -35, 0, 9)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getvapeasset('catsix/assets/new/close.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = window
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
			vape.gui.ScaledGui.ClickGui.Visible = true
		end)
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		local bigslot = Instance.new('Frame')
		bigslot.Size = UDim2.fromOffset(110, 111)
		bigslot.Position = UDim2.fromOffset(11, 71)
		bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		bigslot.Parent = window
		local bigslotcorner = Instance.new('UICorner')
		bigslotcorner.CornerRadius = UDim.new(0, 4)
		bigslotcorner.Parent = bigslot
		local bigslotstroke = Instance.new('UIStroke')
		bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
		bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bigslotstroke.Parent = bigslot
		local slotnum = Instance.new('TextLabel')
		slotnum.Size = UDim2.fromOffset(80, 20)
		slotnum.Position = UDim2.fromOffset(25, 200)
		slotnum.BackgroundTransparency = 1
		slotnum.Text = 'SLOT 1'
		slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
		slotnum.TextSize = 12
		slotnum.FontFace = uipallet.Font
		slotnum.Parent = window
		for i = 1, 9 do
			local slotbkg = Instance.new('TextButton')
			slotbkg.Name = 'Slot'..i
			slotbkg.Size = UDim2.fromOffset(51, 52)
			slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = window
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = ''
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			local slotstroke = Instance.new('UIStroke')
			slotstroke.Color = color.Light(uipallet.Main, 0.04)
			slotstroke.Thickness = 2
			slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			slotstroke.Enabled = i == selectedslot
			slotstroke.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				window['Slot'..selectedslot].UIStroke.Enabled = false
				selectedslot = i
				slotstroke.Enabled = true
				slotnum.Text = 'SLOT '..selectedslot
			end)
			slotbkg.MouseButton2Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..i].ImageLabel.Image = ''
					obj.Hotbar[tostring(i)] = nil
					obj.Object['Slot'..i].Image = '	'
				end
			end)
		end
		local searchbkg = Instance.new('Frame')
		searchbkg.Size = UDim2.fromOffset(496, 31)
		searchbkg.Position = UDim2.fromOffset(142, 80)
		searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		searchbkg.Parent = window
		local search = Instance.new('TextBox')
		search.Size = UDim2.new(1, -10, 0, 31)
		search.Position = UDim2.fromOffset(10, 0)
		search.BackgroundTransparency = 1
		search.Text = ''
		search.PlaceholderText = ''
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.TextColor3 = uipallet.Text
		search.TextSize = 12
		search.FontFace = uipallet.Font
		search.ClearTextOnFocus = false
		search.Parent = searchbkg
		local searchcorner = Instance.new('UICorner')
		searchcorner.CornerRadius = UDim.new(0, 4)
		searchcorner.Parent = searchbkg
		local searchicon = Instance.new('ImageLabel')
		searchicon.Size = UDim2.fromOffset(14, 14)
		searchicon.Position = UDim2.new(1, -26, 0, 8)
		searchicon.BackgroundTransparency = 1
		searchicon.Image = getvapeasset('catsix/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		searchicon.Parent = searchbkg
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.fromOffset(500, 240)
		children.Position = UDim2.fromOffset(144, 122)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.FillDirectionMaxCells = 9
		windowlist.CellSize = UDim2.fromOffset(51, 52)
		windowlist.CellPadding = UDim2.fromOffset(4, 3)
		windowlist.Parent = children
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
		end)
		table.insert(vape.Windows, window)
	
		local function createitem(id, image)
			local slotbkg = Instance.new('TextButton')
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = children
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = image
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..selectedslot].ImageLabel.Image = image
					obj.Hotbar[tostring(selectedslot)] = id
					obj.Object['Slot'..selectedslot].Image = image
				end
			end)
		end
	
		local function indexSearch(text)
			for _, v in children:GetChildren() do
				if v:IsA('TextButton') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			if text == '' then
				for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
					createitem(v, bedwars.ItemMeta[v].image)
				end
				return
			end
	
			for i, v in bedwars.ItemMeta do
				if text:lower() == i:lower():sub(1, text:len()) then
					if not v.image then continue end
					createitem(i, v.image)
				end
			end
		end
	
		search:GetPropertyChangedSignal('Text'):Connect(function()
			indexSearch(search.Text)
		end)
		indexSearch('')
	
		return window
	end
	
	vape.Components.HotbarList = function(optionsettings, children, api)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local optionapi = {
			Type = 'HotbarList',
			Hotbars = {},
			Selected = 1
		}
		local hotbarlist = Instance.new('TextButton')
		hotbarlist.Name = 'HotbarList'
		hotbarlist.Size = UDim2.fromOffset(220, 40)
		hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
		hotbarlist.Text = ''
		hotbarlist.BorderSizePixel = 0
		hotbarlist.AutoButtonColor = false
		hotbarlist.Parent = children
		local textbkg = Instance.new('Frame')
		textbkg.Name = 'BKG'
		textbkg.Size = UDim2.new(1, -20, 0, 31)
		textbkg.Position = UDim2.fromOffset(10, 4)
		textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		textbkg.Parent = hotbarlist
		local textbkgcorner = Instance.new('UICorner')
		textbkgcorner.CornerRadius = UDim.new(0, 4)
		textbkgcorner.Parent = textbkg
		local textbutton = Instance.new('TextButton')
		textbutton.Name = 'HotbarList'
		textbutton.Size = UDim2.new(1, -2, 1, -2)
		textbutton.Position = UDim2.fromOffset(1, 1)
		textbutton.BackgroundColor3 = uipallet.Main
		textbutton.Text = ''
		textbutton.AutoButtonColor = false
		textbutton.Parent = textbkg
		textbutton.MouseEnter:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		textbutton.MouseLeave:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)
		local textbuttoncorner = Instance.new('UICorner')
		textbuttoncorner.CornerRadius = UDim.new(0, 4)
		textbuttoncorner.Parent = textbutton
		local textbuttonicon = Instance.new('ImageLabel')
		textbuttonicon.Size = UDim2.fromOffset(12, 12)
		textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
		textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
		textbuttonicon.BackgroundTransparency = 1
		textbuttonicon.Image = getvapeasset('catsix/assets/new/add.png')
		textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
		textbuttonicon.Parent = textbutton
		local childrenlist = Instance.new('Frame')
		childrenlist.Size = UDim2.new(1, 0, 1, -40)
		childrenlist.Position = UDim2.fromOffset(0, 40)
		childrenlist.BackgroundTransparency = 1
		childrenlist.Parent = hotbarlist
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = childrenlist
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
		end)
		textbutton.MouseButton1Click:Connect(function()
			optionapi:AddHotbar()
		end)
		optionapi.Window = CreateWindow(optionapi)
	
		function optionapi:Save(savetab)
			local hotbars = {}
			for _, v in self.Hotbars do
				table.insert(hotbars, v.Hotbar)
			end
			savetab.HotbarList = {
				Selected = self.Selected,
				Hotbars = hotbars
			}
		end
	
		function optionapi:Load(savetab)
			for _, v in self.Hotbars do
				v.Object:ClearAllChildren()
				v.Object:Destroy()
				table.clear(v.Hotbar)
			end
			table.clear(self.Hotbars)
			for _, v in savetab.Hotbars do
				self:AddHotbar(v)
			end
			self.Selected = savetab.Selected or 1
		end
	
		function optionapi:AddHotbar(data)
			local hotbardata = {Hotbar = data or {}}
			table.insert(self.Hotbars, hotbardata)
			local hotbar = Instance.new('TextButton')
			hotbar.Size = UDim2.fromOffset(200, 27)
			hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
			hotbar.Text = ''
			hotbar.AutoButtonColor = false
			hotbar.Parent = childrenlist
			hotbardata.Object = hotbar
			local hotbarcorner = Instance.new('UICorner')
			hotbarcorner.CornerRadius = UDim.new(0, 4)
			hotbarcorner.Parent = hotbar
			for i = 1, 9 do
				local slot = Instance.new('ImageLabel')
				slot.Name = 'Slot'..i
				slot.Size = UDim2.fromOffset(17, 18)
				slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
				slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				slot.BorderSizePixel = 0
				slot.Parent = hotbar
			end
			hotbar.MouseButton1Click:Connect(function()
				local ind = table.find(optionapi.Hotbars, hotbardata)
				if ind == optionapi.Selected then
					vape.gui.ScaledGui.ClickGui.Visible = false
					optionapi.Window.Visible = true
					for i = 1, 9 do
						optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
					end
				else
					if optionapi.Hotbars[optionapi.Selected] then
						optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
					end
					hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					optionapi.Selected = ind
				end
			end)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getvapeasset('catsix/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local wanted = {}
		for i, v in List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {} do
			wanted[i] = v
			if v == 'diamond_sword' then
				local sword = store.tools.sword
				wanted[i] = sword and sword.itemType or 'wood_sword'
			elseif v == 'diamond_pickaxe' then
				local pickaxe = store.tools.stone
				wanted[i] = pickaxe and pickaxe.itemType or 'wood_pickaxe'
			elseif v == 'diamond_axe' then
				local axe = store.tools.wood
				wanted[i] = axe and axe.itemType or 'wood_axe'
			elseif v == 'wood_bow' then
				local bow = getBow()
				wanted[i] = bow and bow.itemType or 'wood_bow'
			elseif v == 'wool_white' then
				local clone = table.clone(store.inventory.inventory.items)
				table.sort(clone, function(a, b)
					return a.amount < b.amount
				end)
				for _, v2 in clone do
					local block = bedwars.ItemMeta[v2.itemType].block
					if block and not block.seeThrough then
						wanted[i] = v2.itemType
						break
					end
				end
			end
		end
	
		for _, v in store.inventory.inventory.items do
			local slot
			for i2, v2 in wanted do
				if v.itemType == v2 then
					slot = tonumber(i2)
					break
				end
			end
	
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					bedwars.Store:dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
					vapeEvents.InventoryChanged.Event:Wait()
				end
	
				local newslot
				for i, v2 in store.inventory.hotbar do
					if v2.item and v2.item.itemType == v.itemType then
						newslot = i - 1
						break
					end
				end
	
				if newslot then
					bedwars.Store:dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					vapeEvents.InventoryChanged.Event:Wait()
					if olditem.item then
						local swap
						for _, v2 in store.inventory.inventory.items do
							if v2.itemType == olditem.item.itemType then
								swap = v2
								break
							end
						end
						bedwars.Store:dispatch({
							type = 'InventoryAddToHotbar',
							item = swap,
							slot = newslot
						})
						vapeEvents.InventoryChanged.Event:Wait()
					end
				end
	
				local held
				for _, v2 in store.inventory.inventory.items do
					if v2.itemType == v.itemType then
						held = v2
						break
					end
				end
				bedwars.Store:dispatch({
					type = 'InventoryAddToHotbar',
					item = held,
					slot = slot - 1
				})
				vapeEvents.InventoryChanged.Event:Wait()
			elseif Clear.Enabled then
				local newslot
				for i, v2 in store.inventory.hotbar do
					if v2.item and v2.item.itemType == v.itemType then
						newslot = i - 1
						break
					end
				end
	
				if newslot then
					bedwars.Store:dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					vapeEvents.InventoryChanged.Event:Wait()
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'Automatically arranges hotbar to your liking.'
	})
	
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)

run(function()
	local AutoSteal
	local Range
	local Delay
	local GUI
	local Stash = {}
	
	local function stealCrate(crate)
		local value = crate:FindFirstChild('ChestFolderValue')
		local folder = value and value.Value or nil
		if not folder then return end
	
		local items = {}
		for _, v in folder:GetChildren() do
			if v:IsA('Accessory') then
				table.insert(items, v)
			end
		end
		if #items == 0 then return end
	
		local observed = lplr.Character and lplr.Character:FindFirstChild('ObservedChestFolder')
		observed = observed and observed.Value or nil
		bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(folder)
	
		for _, v in items do
			local itemType = v.Name
			task.spawn(function()
				local suc, res = pcall(function()
					return bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(folder, v)
				end)
	
				if suc and res then
					table.insert(Stash, {Type = itemType, Expire = tick() + 5})
				end
			end)
		end
	
		bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(observed)
	end
	
	local function depositStash()
		local inventory = replicatedStorage:FindFirstChild('Inventories')
		inventory = inventory and inventory:FindFirstChild(`{lplr.Name}_personal`) or nil
		if not inventory then return end
	
		local pending = table.clone(Stash)
		table.clear(Stash)
	
		for _, v in pending do
			local item = getItem(v.Type)
			if item then
				task.spawn(function()
					local suc, res = pcall(function()
						return bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(inventory, item.tool)
					end)
	
					if not (suc and res) and tick() < v.Expire then
						table.insert(Stash, v)
					end
				end)
			elseif tick() < v.Expire then
				table.insert(Stash, v)
			end
		end
	end
	
	AutoSteal = vape.Categories.Inventory:CreateModule({
		Name = 'AutoSteal',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoSteal.Enabled)
				if not AutoSteal.Enabled then return end
	
				local crates = collection('team-crate', AutoSteal)
				local chests = collection('personal-chest', AutoSteal)
				local nextSteal = 0
	
				repeat
					if entitylib.isAlive and tick() > nextSteal and (not GUI.Enabled or bedwars.AppController:isAppOpen('ChestApp')) then
						nextSteal = tick() + Delay.Value
						local localPosition = entitylib.character.RootPart.Position
						local team = lplr:GetAttribute('Team')
	
						for _, v in crates do
							if v:GetAttribute('Team') ~= team and (localPosition - v.Position).Magnitude <= Range.Value then
								stealCrate(v)
							end
						end
	
						if #Stash > 0 then
							for _, v in chests do
								if (localPosition - v.Position).Magnitude <= Range.Value then
									depositStash()
									break
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoSteal.Enabled
			end
	
			table.clear(Stash)
		end,
		Tooltip = 'Automatically steals loot from the enemy team\'s crate and banks it in your personal chest'
	})
	
	Range = AutoSteal:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoSteal:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0
	})
	GUI = AutoSteal:CreateToggle({Name = 'GUI Check'})
end)

run(function()
	local AutoUpgrade
	local Upgrades
	local Reserve
	local Delay
	
	local Request = bedwars.Handler:Get('RequestPurchaseTeamUpgrade')
	local names = {}
	for i, v in bedwars.TeamUpgradeMeta or {} do
		names[v.name] = i
	end
	
	AutoUpgrade = vape.Categories.Inventory:CreateModule({
		Name = 'AutoUpgrade',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.matchState == 1 then
						local diamonds = getItem('diamond')
						diamonds = (diamonds and diamonds.amount or 0) - Reserve.Value
	
						for _, v in Upgrades.ListEnabled do
							local upgrade = names[v]
							local meta = upgrade and bedwars.TeamUpgradeMeta[upgrade]
							local tier = meta and (bedwars.Store:getState().Bedwars.myTeamUpgrades[upgrade] or 0)
							local cost = meta and meta.tiers[tier + 1] and meta.tiers[tier + 1].cost
	
							if cost and diamonds >= cost then
								if Request:Fire('CallServer', upgrade) then
									notif('AutoUpgrade', `Bought {meta.name} {tier + 1}`, 3)
									bedwars.AudioManager:playAudio(bedwars.SoundList.BEDWARS_UPGRADE_SUCCESS)
								end
								break
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoUpgrade.Enabled
			end
		end,
		Tooltip = 'Buys your team upgrades as soon as the diamonds are there'
	})
	
	Reserve = AutoUpgrade:CreateSlider({
		Name = 'Reserve',
		Min = 0,
		Max = 32,
		Default = 0,
		Suffix = function(val)
			return val == 1 and 'diamond' or 'diamonds'
		end,
		Tooltip = 'Diamonds to leave alone for the shop'
	})
	Delay = AutoUpgrade:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = 'seconds'
	})
	Upgrades = AutoUpgrade:CreateTextList({
		Name = 'Upgrades',
		Default = {'Damage', 'Armor', 'Team Gen', 'Diamond Gen', 'Break Speed'},
		Darker = true,
		Tooltip = 'Bought top to bottom, drag the ones you want first to the top'
	})
end)

run(function()
	local AutoUse
	local Items
	local Combat
	local Delay
	
	AutoUse = vape.Categories.Inventory:CreateModule({
		Name = 'AutoUse',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.matchState == 1 and not isCasting() and (not Combat.Enabled or (workspace:GetServerTimeNow() - (lplr.Character:GetAttribute('LastDamageTakenTime') or 0)) < 6) then
						for _, v in Items.ListEnabled do
							local item = getItem(v)
							local meta = item and bedwars.ItemMeta[v]
							local consumable = meta and meta.consumable
							if consumable then
								local effect = consumable.statusEffect and consumable.statusEffect.statusEffectType or ({v:gsub('_potion', '')})[1]
								if not lplr.Character:GetAttribute(`StatusEffect_{effect}`) then
									bedwars.Handler:Get('ConsumeItem'):Fire('CallServerAsync', {item = item.tool})
									task.wait(consumable.consumeTime or 1)
									break
								end
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoUse.Enabled
			end
		end,
		Tooltip = 'Drinks and eats the buff items you list as soon as their effect runs out'
	})
	
	Items = AutoUse:CreateTextList({
		Name = 'Items',
		Default = {'fury_potion', 'crit_star', 'vitality_star', 'pie'},
		Tooltip = 'Item ids, anything the game lets you consume\nfury_potion, jump_potion, serpents_touch_potion, crit_star, vitality_star, snow_cone, pie, watermelon, can_of_beans, sparkling_apple_juice'
	})
	Combat = AutoUse:CreateToggle({
		Name = 'In combat only',
		Tooltip = 'Saves them until something has hit you in the last 6 seconds'
	})
	Delay = AutoUse:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds'
	})
end)

run(function()
	local Value
	local oldclickhold, oldshowprogress
	
	local FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			if callback then
				oldclickhold = bedwars.ClickHold.startClick
				oldshowprogress = bedwars.ClickHold.showProgress
				bedwars.ClickHold.startClick = function(self)
					self.startedClickTime = tick()
					local handle = self:showProgress()
					local clicktime = self.startedClickTime
					bedwars.RuntimeLib.Promise.defer(function()
						task.wait(self.durationSeconds * (Value.Value / 40))
						if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
							self:hideProgress()
							if self.onComplete then self.onComplete() end
							if self.onPartialComplete then self.onPartialComplete(1) end
							self.startedClickTime = -1
						end
					end)
				end
	
				bedwars.ClickHold.showProgress = function(self)
					local roact = debug.getupvalue(oldshowprogress, 1)
					local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
						[roact.Ref] = self.wrapperRef,
						Size = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.8
					}, { roact.createElement('Frame', {
						[roact.Ref] = self.progressRef,
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.5
					}) }) }), lplr:FindFirstChild('PlayerGui'))
	
					self.handle = countdown
					local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
						Size = UDim2.fromScale(0.11, 0.005)
					})
					local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1)
					})
	
					sizetween:Play()
					countdowntween:Play()
					table.insert(self.tweens, countdowntween)
					table.insert(self.tweens, sizetween)
	
					return countdown
				end
			else
				bedwars.ClickHold.startClick = oldclickhold
				bedwars.ClickHold.showProgress = oldshowprogress
			end
		end,
		Tooltip = 'Use/Consume items quicker.'
	})
	
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100
	})
end)

run(function()
	local FastDrop
	
	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
						task.spawn(bedwars.ItemDropController.dropItemInHand)
						task.wait()
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			end
		end,
		Tooltip = 'Drops items fast when you hold Q'
	})
end)

run(function()
	local AutoAbaddon
	local Delay
	local Limit
	local Range
	local nextPlace = 0
	
	AutoAbaddon = vape.Categories.Kits:CreateModule({
		Name = 'AutoAbaddon',
		Function = function(callback)
			if callback then
				nextPlace = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'scarab' and tick() >= nextPlace and bedwars.AbilityController:canUseAbility('place_scarab_hive', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local hives = 0
	
						for _, v in collectionService:GetTagged('scarab_spawner') do
							local part = v:IsA('Model') and v.PrimaryPart or v
							if part and part:GetAttribute('PlacedByUserId') == lplr.UserId and (part.Position - origin).Magnitude <= Range.Value then
								hives += 1
							end
						end
	
						if hives < Limit.Value then
							nextPlace = tick() + Delay.Value
							bedwars.AbilityController:useAbility('place_scarab_hive')
						end
					end
					task.wait(0.1)
				until not AutoAbaddon.Enabled
			end
		end,
		Tooltip = 'Keeps scarab hives up around you without spamming the ability'
	})
	
	Limit = AutoAbaddon:CreateSlider({
		Name = 'Hives',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Stops once this many of your hives are already standing nearby'
	})
	Range = AutoAbaddon:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 100,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far out hives still count toward the limit'
	})
	Delay = AutoAbaddon:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1.5,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	
end)

run(function()
	local AutoAdetunde
	local GUI
	
	AutoAdetunde = vape.Categories.Kits:CreateModule({
		Name = 'AutoAdetunde',
		Function = function(callback)
			if callback then
				repeat
					if not GUI.Enabled or bedwars.AppController:isAppOpen('FrostyHammerApp') then
						for i, v in bedwars.AdetundeUtil.getUpgradesFromHammer(lplr) do
							local crystal = getItem('frost_crystal')
							if not crystal then
								break
							end
	
							local nextUpgrade = AutoAdetunde.Options[`Buy {i}`].Enabled and bedwars.AdetundeUpgradeMeta[i].tiers[v + 1]
							if nextUpgrade and crystal.amount >= nextUpgrade.price then
								bedwars.Handler:Get('UpgradeFrostyHammer'):Fire('CallServer', i)
								task.wait(0.1)
							end
						end
					end
					task.wait(0.5)
				until not AutoAdetunde.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades ur frosty hammer'
	})
	
	local upgrades = {}
	for i in bedwars.AdetundeUpgradeMeta do
		table.insert(upgrades, i)
	end
	table.sort(upgrades)
	for _, v in upgrades do
		AutoAdetunde:CreateToggle({
			Name = `Buy {v}`,
			Default = true
		})
	end
	
	GUI = AutoAdetunde:CreateToggle({
		Name = 'GUI Check',
		Tooltip = 'Only upgrades while the frosty hammer menu is open'
	})
end)

run(function()
	local AutoAgni
	local VoidSave
	local Escape
	local Targets
	local Health
	local Range
	local nextBoost = 0
	
	AutoAgni = vape.Categories.Kits:CreateModule({
		Name = 'AutoAgni',
		Function = function(callback)
			if callback then
				nextBoost = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'agni' and tick() >= nextBoost and bedwars.AbilityController:canUseAbility('rocket_detonate', {disableBlockedAbilityAlert = true}) then
						local root = entitylib.character.RootPart
						local humanoid = entitylib.character.Humanoid
						local boost = false
	
						if VoidSave.Enabled and root.AssemblyLinearVelocity.Y <= -20 and not workspace:Raycast(root.Position, Vector3.new(0, -2000, 0), store.airRay) then
							boost = true
						end
	
						if not boost and Escape.Enabled and humanoid.Health <= (humanoid.MaxHealth * (Health.Value / 100)) then
							boost = #entitylib.AllPosition({
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled
							}) > 0
						end
	
						if boost then
							nextBoost = tick() + 1
							bedwars.AbilityController:useAbility('rocket_detonate')
						end
					end
					task.wait(0.05)
				until not AutoAgni.Enabled
			end
		end,
		Tooltip = 'Spends Rocket Boost on saving you from the void and on getting out of fights you are losing'
	})
	
	VoidSave = AutoAgni:CreateToggle({
		Name = 'Void save',
		Default = true,
		Tooltip = 'Boosts the moment you drop off the map with nothing below you'
	})
	Escape = AutoAgni:CreateToggle({
		Name = 'Escape',
		Default = true,
		Function = function(callback)
			if Range then
				Health.Object.Visible = callback
				Range.Object.Visible = callback
				Targets.Object.Visible = callback
			end
		end,
		Tooltip = 'Boosts away once you are low and somebody is on you'
	})
	Targets = AutoAgni:CreateTargets({
		Players = true,
		NPCs = true
	})
	Health = AutoAgni:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 35,
		Suffix = '%'
	})
	Range = AutoAgni:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	
end)

run(function()
	local AutoArachne
	local Targets
	local Range
	local Amount
	
	AutoArachne = vape.Categories.Kits:CreateModule({
		Name = 'AutoArachne',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'spider_queen' and bedwars.AbilityController:canUseAbility('spider_queen_summon_spiders', {disableBlockedAbilityAlert = true}) then
						local found = #entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if found >= Amount.Value then
							bedwars.AbilityController:useAbility('spider_queen_summon_spiders')
						end
					end
					task.wait(0.1)
				until not AutoArachne.Enabled
			end
		end,
		Tooltip = 'Automatically summons spiders once an enemy is nearby'
	})
	
	Targets = AutoArachne:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = AutoArachne:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Amount = AutoArachne:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before summoning'
	})
	
end)

run(function()
	local AutoBee
	local Collect
	local CollectRange
	local CollectDelay
	local Switch
	local LimitCollect
	local Deposit
	local DepositRange
	local DepositDelay
	
	AutoBee = vape.Categories.Kits:CreateModule({
		Name = 'AutoBeekeeper',
		Function = function(callback)
			if callback then
				local hives = collection('beehive', AutoBee)
	
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
	
						if Collect.Enabled and (not LimitCollect.Enabled or store.hand.tool and store.hand.tool.Name == 'bee_net') then
							for _, v in collectionService:GetTagged('bee') do
								local root = v.PrimaryPart or v:FindFirstChild('Root')
								if root and (localPosition - root.Position).Magnitude <= CollectRange.Value then
									local net = Switch.Enabled and getItem('bee_net')
									if net then
										switchItem(net.tool)
									end
									bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {
										beeId = v:GetAttribute('BeeId')
									})
	
									if CollectDelay.Value > 0 then
										task.wait(CollectDelay.Value)
									end
								end
							end
						end
	
						if Deposit.Enabled and getItem('bee') then
							for _, v in hives do
								if not getItem('bee') then
									break
								end
	
								local prompt = v:FindFirstChildWhichIsA('ProximityPrompt')
								if prompt and (v:GetAttribute('Level') or 0) < 10 and v:GetAttribute('PlacedByUserId') == lplr.UserId and (localPosition - v.Position).Magnitude <= DepositRange.Value then
									task.spawn(fireproximityprompt, prompt)
	
									if DepositDelay.Value > 0 then
										task.wait(DepositDelay.Value)
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBee.Enabled
			end
		end,
		Tooltip = 'Automatically deposit bees, and collects nearby bees'
	})
	
	Collect = AutoBee:CreateToggle({
		Name = 'Collect bees',
		Function = function(call)
			if CollectRange then
				CollectRange.Object.Visible = call
				CollectDelay.Object.Visible = call
				Switch.Object.Visible = call
				LimitCollect.Object.Visible = call
			end
		end,
		Default = true
	})
	CollectRange = AutoBee:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 22,
		Default = 20,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	CollectDelay = AutoBee:CreateSlider({
		Name = 'Collect delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true
	})
	Switch = AutoBee:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Darker = true,
		Tooltip = 'Puts the bee net in your hand before catching, the server ignores the catch without it'
	})
	LimitCollect = AutoBee:CreateToggle({
		Name = 'Limit to item',
		Darker = true
	})
	Deposit = AutoBee:CreateToggle({
		Name = 'Deposit bees',
		Function = function(call)
			if DepositRange then
				DepositRange.Object.Visible = call
				DepositDelay.Object.Visible = call
			end
		end,
		Tooltip = 'Automatically puts the bees into a beehive'
	})
	DepositRange = AutoBee:CreateSlider({
		Name = 'Deposit Range',
		Min = 1,
		Max = 14,
		Default = 14,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	DepositDelay = AutoBee:CreateSlider({
		Name = 'Deposit Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local AutoBountyHunter
	local Track
	local Reroll
	local RerollRange
	local Delay
	
	local trackCooldown, rerollCooldown = 0, 0
	local trackAbilities = {'bounty_hunter_4', 'bounty_hunter_3', 'bounty_hunter_2', 'bounty_hunter_1'}
	
	local function getTrackAbility()
		local enabled = bedwars.AbilityController.enabledAbilities
		for _, v in trackAbilities do
			if enabled and enabled[v] then
				return v
			end
		end
	
		local level = bedwars.BountyHunterUtil and bedwars.BountyHunterUtil.getBountyHunterLevel(lplr) or 0
		return 'bounty_hunter_'..math.clamp(level + 1, 1, 4)
	end
	
	local function useAbility(ability)
		if not bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			return false
		end
		bedwars.AbilityController:useAbility(ability)
		return true
	end
	
	AutoBountyHunter = vape.Categories.Kits:CreateModule({
		Name = 'AutoBountyHunter',
		Function = function(callback)
			if callback then
				trackCooldown, rerollCooldown = 0, 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'bounty_hunter' then
						local kit = bedwars.Store:getState().Kit
						local target = kit and kit.bountyHunterTarget
						local ent = target and entitylib.getEntity(target)
	
						if Track.Enabled and target and tick() >= trackCooldown and useAbility(getTrackAbility()) then
							trackCooldown = tick() + Delay.Value
						end
	
						if Reroll.Enabled and tick() >= rerollCooldown then
							local distance = ent and ent.RootPart and (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude or math.huge
							if distance > RerollRange.Value and useAbility('bounty_hunter_reroll') then
								rerollCooldown = tick() + 1
							end
						end
					end
					task.wait(0.1)
				until not AutoBountyHunter.Enabled
			end
		end,
		Tooltip = 'Keeps the bounty tracker up on your target and rerolls bounties you cannot reach'
	})
	
	Track = AutoBountyHunter:CreateToggle({
		Name = 'Auto track',
		Default = true,
		Tooltip = 'Uses the tracking ability whenever it comes off cooldown, the marker lasts 15 seconds'
	})
	Delay = AutoBountyHunter:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds'
	})
	Reroll = AutoBountyHunter:CreateToggle({
		Name = 'Auto reroll',
		Tooltip = 'Rerolls the bounty when your target is dead, gone or further away than the range below'
	})
	RerollRange = AutoBountyHunter:CreateSlider({
		Name = 'Reroll range',
		Min = 10,
		Max = 500,
		Default = 250,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoBuilder
	local Animation
	local Blacklist
	local BedCheck
	local Limit
	
	local function getBed(pos)
		local bed, lastmag = nil, math.huge
		for _, v in collectionService:GetTagged('bed') do
			local mag = (pos - v.Position).Magnitude
			if mag < lastmag and v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				bed, lastmag = v, mag
			end
		end
		return bed
	end
	
	AutoBuilder = vape.Categories.Kits:CreateModule({
		Name = 'AutoBuilder',
		Function = function(callback)
			if callback then
				repeat
					task.wait()
				until store.matchState ~= 0 and store.equippedKit == 'builder' or not AutoBuilder.Enabled
				if not AutoBuilder.Enabled then
					return
				end
	
				local blocks = collection('block', AutoBuilder, function(tab, obj)
					task.delay(0, function()
						if not obj:GetAttribute('NoBreak') and obj:GetAttribute('PlacedByUserId') then
							table.insert(tab, obj)
						end
					end)
				end)
	
				repeat
					if entitylib.isAlive and (not Limit.Enabled and getItem('hammer') or Limit.Enabled and store.hand.tool and store.hand.tool.Name == 'hammer') then
						local bed = getBed(entitylib.character.RootPart.Position)
	
						for _, v in blocks do
							if not BedCheck.Enabled or bed and (bed.Position - v.Position).Magnitude <= 30 then
								local name = v.Name:find('wool_') and 'wool' or v.Name
								if not table.find(Blacklist.ListEnabled, name) and not v:FindFirstChild('BuilderFortify') then
									bedwars.Handler:Get('FortifyBlock'):Fire('SendToServer', ({getPlacedBlock(v.Position)})[2])
	
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.BUILDER_HAMMER_HIT), {
											fadeInTime = 0.02
										})
										bedwars.AudioManager:playAudio(bedwars.SoundList.FORTIFY_BLOCK, {
											position = entitylib.character.RootPart.Position
										})
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBuilder.Enabled
			end
		end,
		Tooltip = 'Automatically fortifies your blocks with the builder hammer'
	})
	
	BedCheck = AutoBuilder:CreateToggle({
		Name = 'Bed Check',
		Tooltip = 'Checks if the block is near your bed'
	})
	Animation = AutoBuilder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays builder visuals (sfx and anim)'
	})
	Limit = AutoBuilder:CreateToggle({
		Name = 'Limit to items',
		Default = true
	})
	Blacklist = AutoBuilder:CreateTextList({
		Name = 'Blacklists',
		Placeholder = 'block',
		Default = {'cannon', 'wool'}
	})
end)

run(function()
	local AutoCaitlyn
	local Mode
	local Range
	local MinHP
	local TargetPriorities
	local activeSession
	
	local function getValidTargets(wallcheck)
		local targets = {}
		for _, v in entitylib.AllPosition({
			Part = 'RootPart',
			Players = true,
			Range = Range.Value,
			Wallcheck = wallcheck
		}) do
			if not (v.Player.Team and v.Player.Team.Name == 'Spectators') then
				targets[v.Player] = v
				targets[v.Character] = v
			end
		end
		return targets
	end
	
	local function getScore(session, contract, targets)
		local ent = targets[contract.target]
		if not ent then
			return nil
		end
	
		local health = ent.Humanoid.Health
		local distance = (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
		local score = 30 + ((tonumber(contract.rewardValue) or 0) * 35)
		score += (1 - math.clamp(health / math.max(ent.Humanoid.MaxHealth, 1), 0, 1)) * 35
		score += math.max(1 - (distance / Range.Value), 0) * 20
	
		if health <= MinHP.Value then
			score += 20
		end
		if (session.threats[ent.Player] or 0) > tick() then
			score += 30
		end
		if ent.Character:GetAttribute('BleedSource') == lplr.UserId then
			score += 25
		end
		local suc, team = pcall(bedwars.TeamController.getPlayerTeam, bedwars.TeamController, ent.Player)
		local teamId = suc and team and team.id or ent.Player:GetAttribute('Team')
		local bed = true
		if teamId ~= nil then
			local cached = session.beds[teamId]
			if cached and cached[2] > tick() then
				bed = cached[1]
			else
				suc, team = pcall(bedwars.BedwarsController.getTeamBed, bedwars.BedwarsController, teamId)
				bed = not suc or team and team.Parent
				session.beds[teamId] = {bed, tick() + 1}
			end
		end
	
		if not bed then
			score += 20
		end
	
		local reward = contract.rewardExplanation
		if type(reward) == 'table' then
			score += (reward.assassin and 10 or 0) + (reward.kitClass and 8 or 0) + (reward.gear and 6 or 0)
		end
		return score, ent
	end
	
	local function getPriorityContract(session, contracts)
		local bounty = false
		for _, v in contracts do
			if v.rewardValue or v.rewardUpgrade then
				bounty = true
				break
			end
		end
		if not bounty then
			return nil, false
		end
	
		local targets = getValidTargets(true)
		local current, currentScore
		if session.priorityId then
			for _, v in contracts do
				if v.id == session.priorityId then
					current, currentScore = v, getScore(session, v, targets)
					break
				end
			end
		end
	
		local best, bestScore
		for _, v in contracts do
			local score = getScore(session, v, targets)
			if score and (not bestScore or score > bestScore) then
				best, bestScore = v, score
			end
		end
	
		if current and currentScore and best ~= current and bestScore < currentScore + 15 then
			best = current
		end
	
		session.priorityId = best and best.id or nil
		return best, true
	end
	
	local function getNormalContract(session, contracts)
		local hit = session.lastHit
		if hit and hit[2] > tick() then
			local ent = getValidTargets(false)[hit[1].Player]
			if ent == hit[1] then
				if Mode.Value == 'On Low' and ent.Humanoid.Health >= MinHP.Value then
					return nil
				end
				for _, v in contracts do
					if v.target == ent.Player or v.target and v.target.Name == ent.Player.Name then
						return v
					end
				end
				return nil
			end
		end
	
		session.lastHit = nil
		return nil
	end
	
	local function updateCaitlyn(session)
		if not entitylib.isAlive or store.matchState ~= 1 or store.equippedKit ~= 'blood_assassin' then
			session.lastHit = nil
			session.pendingId = nil
			session.priorityId = nil
			return
		end
	
		local kit = bedwars.Store:getState().Kit
		if not kit or kit.activeContract then
			session.pendingId = nil
			session.priorityId = kit and kit.activeContract and kit.activeContract.id or nil
			return
		end
	
		if session.pendingId and session.pendingUntil > tick() then
			return
		end
		session.pendingId = nil
	
		local contracts = kit.availableContracts
		if not contracts or #contracts == 0 then
			return
		end
	
		local contract
		if TargetPriorities.Enabled then
			local available
			contract, available = getPriorityContract(session, contracts)
			if not available then
				contract = getNormalContract(session, contracts)
			end
		else
			session.priorityId = nil
			contract = getNormalContract(session, contracts)
		end
		if contract and not (session.pendingId == contract.id and session.pendingUntil > tick()) then
			bedwars.Handler:Get('BloodAssassinSelectContract'):Fire('SendToServer', {
				contractId = contract.id
			})
			session.pendingId = contract.id
			session.pendingUntil = tick() + 1
		end
	end
	
	AutoCaitlyn = vape.Categories.Kits:CreateModule({
		Name = 'AutoCaitlyn',
		Function = function(callback)
			if callback then
				local session = {
					beds = {},
					nextUpdate = 0,
					pendingUntil = 0,
					threats = {}
				}
				activeSession = session
	
				AutoCaitlyn:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if activeSession ~= session then
						return
					end
	
					local source = (typeof(damageTable.fromEntity) == 'Instance' and entitylib.getEntity(damageTable.fromEntity) or nil)
					if damageTable.entityInstance == lplr.Character and source and source.Player then
						session.threats[source.Player] = tick() + 3
					elseif damageTable.fromEntity == lplr.Character or damageTable.fromEntity == lplr then
						local victim = (typeof(damageTable.entityInstance) == 'Instance' and entitylib.getEntity(damageTable.entityInstance) or nil)
						if victim then
							session.lastHit = {victim, tick() + 1}
						end
					end
				end))
	
				AutoCaitlyn:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function()
					table.clear(session.beds)
				end))
	
				AutoCaitlyn:Clean(entitylib.Events.LocalAdded:Connect(function()
					session.lastHit = nil
					session.pendingId = nil
				end))
	
				AutoCaitlyn:Clean(entitylib.Events.LocalRemoved:Connect(function()
					session.lastHit = nil
					session.pendingId = nil
					session.priorityId = nil
				end))
	
				repeat
					if tick() >= session.nextUpdate then
						session.nextUpdate = tick() + 0.2
						updateCaitlyn(session)
					end
					task.wait(0.05)
				until not AutoCaitlyn.Enabled or activeSession ~= session
	
				if activeSession == session then
					activeSession = nil
				end
			else
				activeSession = nil
			end
		end,
		Tooltip = 'Automatically assigns a player\'s contract when a specific action happens'
	})
	
	Mode = AutoCaitlyn:CreateDropdown({
		Name = 'Contract mode',
		List = {'On Hit', 'On Low'},
		Function = function(val)
			if MinHP then
				MinHP.Object.Visible = val == 'On Low'
			end
		end,
		Default = 'On Low',
		Tooltip = 'On Hit - Contracts them whenever u start hitting them\nOn Low - When they\'re low'
	})
	MinHP = AutoCaitlyn:CreateSlider({
		Name = 'Minimum Health',
		Tooltip = 'How low they have to be before contracting',
		Min = 1,
		Max = 100,
		Default = 30,
		Darker = true,
		Visible = false
	})
	Range = AutoCaitlyn:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	TargetPriorities = AutoCaitlyn:CreateToggle({
		Name = 'Target Priorities',
		Function = function()
			if activeSession then
				activeSession.priorityId = nil
			end
		end
	})
end)

run(function()
	local AutoCard
	local Range
	local Delay
	local nextThrow = 0
	
	AutoCard = vape.Categories.Kits:CreateModule({
		Name = 'AutoCard',
		Function = function(callback)
			if callback then
				nextThrow = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'card' and tick() >= nextThrow and bedwars.AbilityController:canUseAbility('CARD_THROW', {disableBlockedAbilityAlert = true}) then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
	
						if target then
							nextThrow = tick() + Delay.Value
							bedwars.AbilityController:useAbility('CARD_THROW')
						end
					end
					task.wait(0.1)
				until not AutoCard.Enabled
			end
		end,
		Tooltip = 'Automatically throws Fortuna cards at whoever is near you'
	})
	
	Range = AutoCard:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoCard:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.4,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoCogsworth
	local Targets
	local Collect
	local Steal
	local Range
	local Delay
	local Overclock
	local OverclockRange
	local nextCollect = 0
	local nextOverclock = 0
	
	local function getBots()
		local controller = bedwars.GatherBotBasicController
		return controller and controller.gatherBotMap or {}
	end
	
	AutoCogsworth = vape.Categories.Kits:CreateModule({
		Name = 'AutoCogsworth',
		Function = function(callback)
			if callback then
				nextCollect = 0
				nextOverclock = 0
	
				repeat
					if entitylib.isAlive then
						local origin = entitylib.character.RootPart.Position
	
						if Collect.Enabled and tick() >= nextCollect then
							for bot in getBots() do
								if not bot.Parent then continue end
								local owner = bot:GetAttribute('PlacedByUserId')
								if not Steal.Enabled and owner ~= lplr.UserId then continue end
								if (bot:GetAttribute('HeldItemAmount') or 0) <= 0 then continue end
								if (bot:GetPivot().Position - origin).Magnitude > Range.Value then continue end
	
								bedwars.Handler:Get('GatherBotCollectItems'):Fire('SendToServer', {
									player = lplr,
									gatherBot = bot
								})
								nextCollect = tick() + Delay.Value
								break
							end
						end
	
						if Overclock.Enabled and store.equippedKit == 'steam_engineer' and tick() >= nextOverclock and bedwars.AbilityController:canUseAbility('STEAM_ENGINEER_OVERCLOCK', {disableBlockedAbilityAlert = true}) then
							local found = #entitylib.AllPosition({
								Range = OverclockRange.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled
							}) > 0
	
							if found then
								nextOverclock = tick() + 1
								bedwars.AbilityController:useAbility('STEAM_ENGINEER_OVERCLOCK')
							end
						end
					end
					task.wait(0.1)
				until not AutoCogsworth.Enabled
			end
		end,
		Tooltip = 'Empties gather bots from across the map and overclocks when a fight starts'
	})
	
	Targets = AutoCogsworth:CreateTargets({
		Players = true,
		NPCs = true
	})
	Collect = AutoCogsworth:CreateToggle({
		Name = 'Collect bots',
		Default = true,
		Tooltip = 'The games own collect prompt stops at 10 studs, the server never checks it'
	})
	Steal = AutoCogsworth:CreateToggle({
		Name = 'Steal enemy bots',
		Tooltip = 'Also empties gather bots that somebody else placed'
	})
	Range = AutoCogsworth:CreateSlider({
		Name = 'Range',
		Min = 5,
		Max = 500,
		Default = 250,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoCogsworth:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Overclock = AutoCogsworth:CreateToggle({
		Name = 'Overclock',
		Default = true,
		Function = function(callback)
			if OverclockRange then
				OverclockRange.Object.Visible = callback
			end
		end
	})
	OverclockRange = AutoCogsworth:CreateSlider({
		Name = 'Overclock range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	
end)

run(function()
	local AutoCrocowolf
	local Range
	local Targets
	
	AutoCrocowolf = vape.Categories.Kits:CreateModule({
		Name = 'AutoCrocowolf',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'beast' and bedwars.AbilityController:canUseAbility('beast_form', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end
	
						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('beast_form')
						end
					end
					task.wait(0.1)
				until not AutoCrocowolf.Enabled
			end
		end,
		Tooltip = 'Automatically goes into beast form once enough enemies are around you'
	})
	
	Range = AutoCrocowolf:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoCrocowolf:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before transforming'
	})
end)

run(function()
	local AutoCyber
	local Mode
	local Whitelist
	local Visual
	local Steal
	local Target
	local Limit
	
	local teamCache, cacheExpire = nil, 0
	local function getTeamGenerator()
		if cacheExpire > tick() and teamCache and teamCache.Parent then
			return teamCache
		end
		teamCache, cacheExpire = collectionService:GetTagged(lplr:GetAttribute('Team').. '_TeamOreGenerator')[1], tick() + 5
		return teamCache
	end
	local cache = nil
	local watching = setmetatable({}, {__mode = 'k'})
	local function getDrone()
		if Limit.Enabled and (not store.hand.tool or store.hand.tool.Name ~= 'drone') then
			return nil
		end
		if cache and cache.Parent then
			return cache
		end
		for _, v in collectionService:GetTagged('Drone') do
			if v:GetAttribute('PlayerUserId') == lplr.UserId then
				local function Changed()
					if v:GetAttribute('HeldItem') then
						repeat
							bedwars.Handler:Get('DropDroneItem'):Fire('SendToServer', {
								direction = Vector3.new(1000, 10, 0),
								position = v.PrimaryPart.Position
							})
							task.wait(0.1)
						until not v:GetAttribute('HeldItem') or not AutoCyber.Enabled
					end
				end
				if not watching[v] then
					watching[v] = {
						v:GetAttributeChangedSignal('HeldItem'):Connect(Changed),
						v:GetAttributeChangedSignal('HeldItemAmount'):Connect(Changed)
					}
				end
				cache = v
				return v
			end
		end
		if getItem('drone') and bedwars.Handler:Get('FireGuidedProjectile'):Fire('CallServer', 'drone') then
			task.wait(0.1)
			return getDrone()
		end
		return nil
	end
	local blacklist = {}
	local function getItemDrop(drone)
		local generator = getTeamGenerator()
		generator = generator and generator.PrimaryPart.Position or Vector3.zero
		local children = workspace.ItemDrops:GetChildren()
		local pos = drone.PrimaryPart.Position
		table.sort(children, function(a, b)
			return (pos - a.Position).Magnitude < (pos - b.Position).Magnitude
		end)
		for _, v in children do
			if tick() > (blacklist[v] or 0) and table.find(Whitelist.ListEnabled, v.Name) and v.Position.Y > 0 and math.abs(v.AssemblyLinearVelocity.Y) <= 0 and (not Steal.Enabled or (v.Position - generator).Magnitude > 20) and (not Target.Enabled or not entitylib.EntityPosition({
				Origin = pos,
				Range = 60,
				Part = 'RootPart',
				Players = true
			})) then
				return v
			end
		end
		return nil
	end
	AutoCyber = vape.Categories.Kits:CreateModule({
		Name = 'AutoCyber',
		Function = function(callback)
			if callback then
				AutoCyber:Clean(workspace.ItemDrops.ChildAdded:Connect(function(v)
					task.wait()
					if v.AssemblyLinearVelocity.X > 100 then
						blacklist[v] = tick() + 5
						local Amount = v:GetAttribute('Amount')
						local LastParent = v.Parent
						if Mode.Value == 'Player' then
							notif('AutoCyber', 'Collecting '.. tostring(Amount).. ' '.. v.Name, 4, 'info')
							repeat
								v.AssemblyLinearVelocity = Vector3.zero
								v.CFrame = entitylib.character.RootPart.CFrame - Vector3.new(0, 4, 0)
								task.spawn(function()
									bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.AudioManager:playAudio(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.AudioManager:playAudio(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
								task.wait(0.02)
							until not v or v.Parent ~= LastParent
	
							notif('AutoCyber', `Collected {Amount} {v.Name}{Amount > 1 and 's' or ''}`, 4, 'info')
						else
							local start = tick()
							local generator = getTeamGenerator()
							if generator then
								repeat
									v.AssemblyLinearVelocity = Vector3.zero
									v.CFrame = generator.PrimaryPart.CFrame
									task.wait()
								until (tick() - start) >= 1 or not v or v.Parent ~= LastParent
								notif('AutoCyber', 'Dropped '.. tostring(Amount).. ' '.. v.Name, 8, 'info')
							else
								notif('AutoCyber', 'Generator not found', 20, 'alert')
							end
						end
					end
				end))
	
				repeat
					local drone = getDrone()
					if drone then
						local v = getItemDrop(drone)
						if v then
							task.wait(0.3)
							local highlight
							if Visual.Enabled then
								highlight = Instance.new('Highlight')
								highlight.FillColor = Color3.new(1, 1, 1)
								highlight.FillTransparency = 0
								highlight.OutlineTransparency = 0.5
								highlight.OutlineColor = Color3.new()
							end
							drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
							drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 10000, drone.PrimaryPart.CFrame.Z)
							local magnitude, lastmag = 0, 9e9
							local pos = v.Position
							repeat
								if drone and drone.Parent then
									pos = v.Position
									local multi = drone:GetAttribute('SpeedBoost')
									multi = multi == 0 or multi == '' or not multi and true or false
									drone.PrimaryPart.CanCollide = false
									drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
									drone.PrimaryPart.AssemblyLinearVelocity = CFrame.lookAt(drone.PrimaryPart.Position * Vector3.new(1, 0, 1), pos * Vector3.new(1, 0, 1)).LookVector * 30
									magnitude = ((drone.PrimaryPart.Position * Vector3.new(1, 0, 1)) - (pos * Vector3.new(1, 0, 1))).Magnitude
									if (lastmag - magnitude) >= 25 then
										lastmag = magnitude
										notif('AutoCyber', `Drone is {math.floor(magnitude)} studs away from {v.Name}.`, 1, 'info')
									end
								else
									break
								end
								task.wait()
							until not v or v.Parent ~= workspace.ItemDrops or not AutoCyber.Enabled or magnitude <= 2
							if not AutoCyber.Enabled then
								if highlight and highlight.Parent then
									highlight:Destroy()
								end
								break
							end
	
							if magnitude <= 5 then
								local start = tick()
								if Visual.Enabled then
									notif('AutoCyber', 'Attempting to collect '.. v.Name, 4, 'info')
								end
								repeat
									if drone and drone.Parent then
										drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
										drone.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, -30, 0)
										drone.PrimaryPart.CFrame = CFrame.new(pos - Vector3.new(0, drone.Hitbox.Size.Y, 0))
									end
									task.wait(0.02)
								until (tick() - start) >= 1.25
							elseif Visual.Enabled then
								notif('AutoCyber', `Too far away to collect {v.Name} ({magnitude} studs).`, 8, 'info')
							end
							if highlight and highlight.Parent then
								highlight:Destroy()
							end
						else
							drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 10000, drone.PrimaryPart.CFrame.Z)
							drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
							for _, v2 in Whitelist.ListEnabled do
								local item = v2
								local children = collectionService:GetTagged(item.. '_OreGenerator')
								local pos = drone.PrimaryPart.Position
								table.sort(children, function(a, b)
								local gen = (pos - a.PrimaryPart.Position).Magnitude < (pos - b.PrimaryPart.Position).Magnitude
								end)
								local gen = children[1] and children[1].PrimaryPart or nil
								if gen then
									local magnitude = 0
									repeat
										if drone and drone.Parent then
											if getItemDrop(drone) then break end
											drone.PrimaryPart.CanCollide = false
											drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
											drone.PrimaryPart.AssemblyLinearVelocity = CFrame.lookAt(drone.PrimaryPart.Position * Vector3.new(1, 0, 1), gen.Position * Vector3.new(1, 0, 1)).LookVector * 30
											magnitude = ((drone.PrimaryPart.Position * Vector3.new(1, 0, 1)) - (gen.Position * Vector3.new(1, 0, 1))).Magnitude
										else
											break
										end
										task.wait()
									until not v or v.Parent ~= workspace.ItemDrops or not AutoCyber.Enabled or magnitude <= 5
								end
							end
						end
					end
					task.wait()
				until not AutoCyber.Enabled
			else
				local drone = getDrone()
				if drone then
					drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 500, drone.PrimaryPart.CFrame.Z)
				end
			end
		end,
		Tooltip = 'Allows you to steal other\'s opponent resources via drone.'
	})
	
	Mode = AutoCyber:CreateDropdown({
		Name = 'Drop mode',
		List = {'Player', 'Generator'},
		Default = 'Player',
		Tooltip = 'Where cyber items gets dropped to.'
	})
	Whitelist = AutoCyber:CreateTextList({
		Name = 'Whitelist',
		Default = {'emerald', 'diamond'}
	})
	Visual = AutoCyber:CreateToggle({
		Name = 'Visualize',
		Default = true,
		Tooltip = 'Shows what item the drone is targeting and updates\non where how far the drone is to the item.'
	})
	Steal = AutoCyber:CreateToggle({
		Name = 'Steal split',
		Default = true,
		Tooltip = 'Steals other opponent team\'s generator split.'
	})
	Target = AutoCyber:CreateToggle({Name = 'Target check'})
	Limit = AutoCyber:CreateToggle({Name = 'Limit to item'})
end)

run(function()
	local AutoDavey
	local Switch
	local Break
	local Jump
	local LimitItem
	
	local old, oldAim
	
	local function canBreak()
		if not LimitItem.Enabled then return true end
		local itemmeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
		return itemmeta ~= nil and itemmeta.breakBlock ~= nil
	end
	
	local function breakCannon(block, keepLast)
		local deadline = tick() + 0.6 + (store.ping.total or 0)
		local hits = keepLast and math.max(math.ceil(getBlockHits(block, block.Position)) - 1, 0) or math.huge
	
		repeat
			if not AutoDavey.Enabled or not entitylib.isAlive or not canBreak() or hits <= 0 then return end
			if (block.Position - entitylib.character.RootPart.Position).Magnitude > 30 then return end
			bedwars.breakBlock(block, true, true, nil, Switch.Enabled)
			hits -= 1
			task.wait(0.1)
		until not block.Parent or tick() > deadline
	end
	
	AutoDavey = vape.Categories.Kits:CreateModule({
		Name = 'AutoDavey',
		Function = function(callback)
			if callback then
				oldAim = bedwars.CannonController.startAiming
				bedwars.CannonController.startAiming = function(self, block, ...)
					local call = oldAim(self, block, ...)
	
					if Break.Enabled and block and block.Parent and entitylib.isAlive and canBreak() and getBlockHits(block, block.Position) > 1 then
						task.spawn(breakCannon, block, true)
					end
	
					return call
				end
	
				old = bedwars.CannonHandController.launchSelf
				bedwars.CannonHandController.launchSelf = function(self, block, ...)
					if Break.Enabled and block and block.Parent and entitylib.isAlive and (block.Position - entitylib.character.RootPart.Position).Magnitude <= 30 and canBreak() then
						pcall(breakCannon, block, true)
						task.spawn(breakCannon, block)
					end
	
					local call = old(self, block, ...)
	
					if Jump.Enabled and entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					return call
				end
			else
				bedwars.CannonHandController.launchSelf = old
				bedwars.CannonController.startAiming = oldAim
			end
		end,
		Tooltip = 'Automatically breaks cannon/jump on launch'
	})
	
	Jump = AutoDavey:CreateToggle({Name = 'Jump on impact'})
	
	Break = AutoDavey:CreateToggle({Name = 'Break on impact'})
	
	Switch = AutoDavey:CreateToggle({Name = 'Legit switch'})
	
	LimitItem = AutoDavey:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
end)

run(function()
	local AutoDragonSword
	local Range
	local Targets
	
	AutoDragonSword = vape.Categories.Kits:CreateModule({
		Name = 'AutoDragonSword',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'dragon_sword' and bedwars.AbilityController:canUseAbility('dragon_sword_ult', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end
	
						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('dragon_sword_ult')
						end
					end
					task.wait(0.1)
				until not AutoDragonSword.Enabled
			end
		end,
		Tooltip = 'Automatically uses Lian ultimate once enough enemies are around you'
	})
	
	Range = AutoDragonSword:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoDragonSword:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before using the ultimate'
	})
end)

run(function()
	local AutoDrill
	local AutoCollect
	local Notify
	local AutoAttack
	local Legit
	local Range
	local AttackDelay
	local CollectDelay
	local Targets
	local Sort
	local currentDrill
	local attackDebounce = {}
	local collectDebounce = {}
	
	local function addDrill(drills, added, drill)
		if typeof(drill) ~= 'Instance' or added[drill] or drill:GetAttribute('PlacedByUserId') ~= lplr.UserId then
			return
		end
		if (drill and (drill.PrimaryPart or drill:FindFirstChild('RootPart') or drill:FindFirstChildWhichIsA('BasePart'))) then
			added[drill] = true
			table.insert(drills, drill)
		end
	end
	
	local function getDrills(tagged)
		local drills, added = {}, {}
		for _, v in tagged do
			addDrill(drills, added, v)
		end
	
		for _, v in (bedwars.DrillTabletController and bedwars.DrillTabletController.drillList or {}) do
			addDrill(drills, added, v)
		end
	
		return drills
	end
	
	local function updateAttackControls()
		if Legit then
			local enabled = AutoAttack.Enabled
			Legit.Object.Visible = enabled
			Range.Object.Visible = enabled and not Legit.Enabled
			AttackDelay.Object.Visible = enabled
			Targets.Object.Visible = enabled
			Sort.Object.Visible = enabled
		end
	end
	
	AutoDrill = vape.Categories.Kits:CreateModule({
		Name = 'AutoDrill',
		Function = function(callback)
			if callback then
				local tagged = collection('Drill', AutoDrill)
				repeat
					task.wait()
				until store.matchState ~= 0 and store.equippedKit == 'drill' or not AutoDrill.Enabled
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'drill' then
						local now = tick()
						for _, v in getDrills(tagged) do
							local part = (v and (v.PrimaryPart or v:FindFirstChild('RootPart') or v:FindFirstChildWhichIsA('BasePart')))
							if not part then
								continue
							end
	
							if AutoCollect.Enabled and ((v:GetAttribute('diamond') or 0) + (v:GetAttribute('emerald') or 0)) > 0 and now > (collectDebounce[v] or 0) then
								bedwars.Handler:Get('ExtractFromDrill'):Fire('SendToServer', {v = v})
								collectDebounce[v] = now + CollectDelay.Value
	
								if Notify.Enabled then
									notif('Auto Drill', 'Collected v resources', 4, 'info')
								end
							end
	
							if AutoAttack.Enabled and now > (attackDebounce[v] or 0) then
								local target = entitylib.EntityPosition({
									Origin = part.Position,
									Range = Legit.Enabled and 10 or Range.Value,
									Part = 'RootPart',
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Priority = Targets.Priority.Value,
									Sort = sortmethods[Sort.Value]
								})
	
								local using = currentDrill == v
								if target and not using and bedwars.Handler:Get('PlayerUseDrillController'):Fire('CallServer', {drill = v}) ~= false then
									currentDrill = v
									using = true
								end
	
								if target and using then
									targetinfo.Targets[target] = tick() + 1
									bedwars.Handler:Get('DrillAttack'):Fire('SendToServer', {targetPosition = target.RootPart.Position})
									attackDebounce[v] = now + AttackDelay.Value
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoDrill.Enabled
			else
				currentDrill = nil
				table.clear(attackDebounce)
				table.clear(collectDebounce)
			end
		end,
		Tooltip = 'Automatically collects resources and attacks with placed drills.'
	})
	
	AutoCollect = AutoDrill:CreateToggle({
		Name = 'Auto collect',
		Function = function(callback)
			if Notify then
				Notify.Object.Visible = callback
				CollectDelay.Object.Visible = callback
			end
		end,
		Default = true
	})
	Notify = AutoDrill:CreateToggle({
		Name = 'Notify on collect',
		Darker = true
	})
	AutoAttack = AutoDrill:CreateToggle({
		Name = 'Auto attack',
		Function = updateAttackControls,
		Default = true
	})
	Range = AutoDrill:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(value)
			return value == 1 and 'stud' or 'studs'
		end
	})
	Legit = AutoDrill:CreateToggle({
		Name = 'Legit Range',
		Function = updateAttackControls,
		Default = true
	})
	AttackDelay = AutoDrill:CreateSlider({
		Name = 'Attack delay',
		Min = 0.1,
		Max = 1,
		Default = 0.3,
		Decimal = 100,
		Suffix = function(value)
			return value == 1 and 'sec' or 'secs'
		end
	})
	CollectDelay = AutoDrill:CreateSlider({
		Name = 'Collect delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(value)
			return value == 1 and 'sec' or 'secs'
		end
	})
	Targets = AutoDrill:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Distance', 'Health', 'Damage'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AutoDrill:CreateDropdown({
		Name = 'Sort',
		List = methods,
		Default = 'Distance'
	})
	updateAttackControls()
end)

run(function()
	local AutoElder
	local Streamer
	local Range
	local Animation
	local Delay
	
	local Legit = getFunctionRange(bedwars.EldertreeController.createTreeOrbInteraction) or 10
	local cooldowns = {}
	
	AutoElder = vape.Categories.Kits:CreateModule({
		Name = 'AutoElder',
		Function = function(call)
			if call then
				AutoElder:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'treeOrb' then
						task.delay(0.1, prompt.InputHoldBegin, prompt)
					end
				end))
	
				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('treeOrb') do
							local orbPosition = v.Parent and v:GetPivot().Position
							if orbPosition and tick() > (cooldowns[v] or 0) and (localPosition - orbPosition).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
	
								if v.Parent and (entitylib.character.RootPart.Position - v:GetPivot().Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
										bedwars.AudioManager:playAudio(bedwars.SoundList.CROP_HARVEST)
									end
	
									if bedwars.Handler:Get('ConsumeTreeOrb'):Fire('CallServer', {treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
										v:Destroy()
									end
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoElder.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically collects tree orbs'
	})
	
	Streamer = AutoElder:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Delay then
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Useful for when ur screensharing'
	})
	Animation = AutoElder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoElder:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoElder:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoElder:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoEldric
	local Targets
	local Range
	local Priority
	local Allies
	local Health
	local linked
	
	local Link = bedwars.Handler:Get('WarlockLinkTarget')
	
	local function getHurtAlly(origin)
		local best, bestHealth
		for _, v in entitylib.List do
			if not v.Targetable and v.Player and v ~= entitylib.character and (v.RootPart.Position - origin).Magnitude <= Range.Value then
				local ratio = v.Health / v.MaxHealth
				if ratio <= (Health.Value / 100) and (not bestHealth or ratio < bestHealth) then
					best, bestHealth = v, ratio
				end
			end
		end
		return best
	end
	
	AutoEldric = vape.Categories.Kits:CreateModule({
		Name = 'AutoEldric',
		Function = function(callback)
			if callback then
				linked = nil
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'warlock' and store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
						local origin = entitylib.character.RootPart.Position
						local target
	
						if Priority.Value == 'Teammates' and Allies.Enabled then
							target = getHurtAlly(origin)
						end
	
						if not target then
							target = entitylib.EntityPosition({
								Origin = origin,
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Priority = Targets.Priority.Value,
								Wallcheck = Targets.Walls.Enabled
							})
						end
	
						if not target and Allies.Enabled then
							target = getHurtAlly(origin)
						end
	
						if target and target.Character ~= linked then
							if bedwars.AbilityController:canUseAbility('WARLOCK_LINK', {disableBlockedAbilityAlert = true}) then
								bedwars.AbilityController:useAbility('WARLOCK_LINK')
								task.wait(store.ping.total or 0.1)
							end
	
							if AutoEldric.Enabled and target.Character and target.Character.Parent then
								linked = target.Character
								Link:Fire('CallServer', {target = target.Character})
							end
						elseif not target then
							linked = nil
						end
					end
					task.wait(0.1)
				until not AutoEldric.Enabled
			end
		end,
		Tooltip = 'Automatically links the warlock staff to enemies or hurt teammates'
	})
	
	Targets = AutoEldric:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoEldric:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 24,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoEldric:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(bedwars.WarlockBalance and bedwars.WarlockBalance.SELECTOR_RANGE or 24)
		end
	})
	Priority = AutoEldric:CreateDropdown({
		Name = 'Priority',
		List = {'Enemies', 'Teammates'},
		Tooltip = 'Which side the staff links first when both are in range'
	})
	Allies = AutoEldric:CreateToggle({
		Name = 'Heal teammates',
		Default = true,
		Tooltip = 'Links a hurt teammate when no enemy is in range'
	})
	Health = AutoEldric:CreateSlider({
		Name = 'Ally health',
		Min = 1,
		Max = 100,
		Default = 70,
		Darker = true,
		Suffix = function()
			return '%'
		end
	})
end)

run(function()
	local AutoElektra
	local Targets
	local Range
	local Face
	local nextDash = 0
	
	AutoElektra = vape.Categories.Kits:CreateModule({
		Name = 'AutoElektra',
		Function = function(callback)
			if callback then
				nextDash = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'elektra' and tick() >= nextDash and bedwars.AbilityController:canUseAbility('ELECTRIC_DASH', {disableBlockedAbilityAlert = true}) then
						local target = entitylib.EntityPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Wallcheck = Targets.Walls.Enabled,
							Sort = sortmethods.Distance
						})
	
						if target then
							if Face.Enabled then
								local root = entitylib.character.RootPart
								root.CFrame = CFrame.lookAlong(root.Position, (target.RootPart.Position - root.Position) * Vector3.new(1, 0, 1))
							end
	
							nextDash = tick() + 0.5
							bedwars.AbilityController:useAbility('ELECTRIC_DASH')
						end
					end
					task.wait(0.1)
				until not AutoElektra.Enabled
			end
		end,
		Tooltip = 'Spends your dash charges on whoever walks into range'
	})
	
	Targets = AutoElektra:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoElektra:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Face = AutoElektra:CreateToggle({
		Name = 'Face target',
		Default = true,
		Tooltip = 'Turns you at them first so the dash actually goes through them'
	})
	
end)

run(function()
	local AutoEmber
	local Targets
	local Range
	local Delay
	local Limit
	
	AutoEmber = vape.Categories.Kits:CreateModule({
		Name = 'AutoEmber',
		Function = function(call)
			if call then
				local clock = os.clock()
	
				repeat
					local tool = entitylib.isAlive and getItem('infernal_saber')
					if tool and (not Limit.Enabled or store.hand.tool == tool) and (Delay.Value <= 0 or os.clock() - clock >= Delay.Value) and entitylib.EntityPosition({
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value
					}) then
						bedwars.Handler:Get('HellBladeRelease'):Fire('SendToServer', {
							chargeTime = 1,
							weapon = tool,
							player = lplr
						})
						clock = os.clock()
					end
					task.wait()
				until not AutoEmber.Enabled
			end
		end,
		Tooltip = 'Automatically releases the infernal saber charge when a target is in range'
	})
	
	Targets = AutoEmber:CreateTargets({
		Players = true,
		NPCs = false
	})
	Delay = AutoEmber:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	Range = AutoEmber:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Limit = AutoEmber:CreateToggle({Name = 'Limit to item'})
end)

run(function()
	local AutoEquipKit
	local Kit
	
	local kits, list = {}, {}
	
	for i, v in bedwars.BedwarsKitMeta do
		if v.name ~= 'None' then
			table.insert(list, v.name)
		end
		kits[v.name] = i
	end
	table.sort(list)
	table.insert(list, 1, 'None')
	
	AutoEquipKit = vape.Categories.Kits:CreateModule({
		Name = 'AutoEquipKit',
		Function = function(callback)
			if callback then
				local last
	
				repeat
					if store.matchState == 2 and last == 1 and Kit.Value ~= 'None' then
						bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = kits[Kit.Value]})
						notif('AutoEquipKit', `Equipped {Kit.Value} for the next round.`, 10, 'info')
					end
	
					last = store.matchState
					task.wait(0.5)
				until not AutoEquipKit.Enabled
			end
		end,
		Tooltip = 'Equips a kit automatically when a round ends'
	})
	
	Kit = AutoEquipKit:CreateDropdown({
		Name = 'Equip kit',
		List = list,
		Default = 'None'
	})
end)

run(function()
	local AutoEvelynn
	local Range
	local Delay
	local EnemyCheck
	
	local Legit = getFunctionRange(bedwars.SpiritAssassinController.onKitLocalActivated) or 120
	
	AutoEvelynn = vape.Categories.Kits:CreateModule({
		Name = 'AutoEvelynn',
		Function = function(callback)
			if callback then
				local spirits = collection('EvelynnSoul', AutoEvelynn)
				local cooldown = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'spirit_assassin' and (Delay.Value <= 0 or tick() - cooldown >= Delay.Value) and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'grounded') and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'frosted') then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in spirits do
							local pos = v:GetPivot().Position
							if (localPosition - pos).Magnitude <= Range.Value and (not EnemyCheck.Enabled or entitylib.EntityPosition({Origin = pos, Range = 18, Part = 'RootPart', Players = true, NPCs = true})) then
								bedwars.Handler:Get('UseSpirit'):Fire('CallServer', {
									secret = v:GetAttribute('SpiritSecret')
								})
								cooldown = tick()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoEvelynn.Enabled
			end
		end,
		Tooltip = 'Eats nearby spirits so you teleport onto whoever you damaged'
	})
	
	Range = AutoEvelynn:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoEvelynn:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoEvelynn:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
	EnemyCheck = AutoEvelynn:CreateToggle({
		Name = 'Enemy check',
		Tooltip = 'Only eats a spirit while somebody is still standing next to it'
	})
end)

run(function()
	local AutoFarmer
	local Harvest
	local Collect
	local Range
	local Delay
	local nextAction = 0
	
	local drops = {
		carrot = true,
		carrot_seeds = true,
		melon = true,
		melon_seeds = true,
		watermelon = true,
		pumpkin = true,
		pumpkin_block = true,
		pumpkin_seeds = true
	}
	
	local function harvestCrop(origin)
		for _, v in collectionService:GetTagged('HarvestableCrop') do
			local owner = v:GetAttribute('PlacedByUserId') or 0
			local player = owner ~= 0 and playersService:GetPlayerByUserId(owner)
			if v:IsA('BasePart') and (v.Position - origin).Magnitude <= Range.Value and (not player or player:GetAttribute('Team') == lplr:GetAttribute('Team')) then
				bedwars.Handler:Get('CropHarvest'):Fire('CallServer', {
					position = bedwars.BlockController:getBlockPosition(v.Position)
				})
				return true
			end
		end
		return false
	end
	
	local function collectDrop(origin)
		for _, v in collectionService:GetTagged('ItemDrop') do
			if drops[v.Name] and (v:GetAttribute('PickupReadyTime') or math.huge) < workspace:GetServerTimeNow() and (v.Position - origin).Magnitude <= Range.Value then
				bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {itemDrop = v})
				return true
			end
		end
		return false
	end
	
	AutoFarmer = vape.Categories.Kits:CreateModule({
		Name = 'AutoFarmer',
		Function = function(callback)
			if callback then
				nextAction = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextAction then
						local origin = entitylib.character.RootPart.Position
						if (Harvest.Enabled and harvestCrop(origin)) or (Collect.Enabled and collectDrop(origin)) then
							nextAction = tick() + Delay.Value
						end
					end
					task.wait(0.1)
				until not AutoFarmer.Enabled
			end
		end,
		Tooltip = 'Harvests your ripe crops and picks up what they drop'
	})
	
	Harvest = AutoFarmer:CreateToggle({
		Name = 'Harvest crops',
		Default = true,
		Tooltip = 'Reaps anything ripe, the same call the Harvest prompt makes'
	})
	Collect = AutoFarmer:CreateToggle({
		Name = 'Collect drops',
		Default = true,
		Tooltip = 'Picks up the crops and seeds lying on the ground'
	})
	Range = AutoFarmer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'The games own harvest prompt stops at 6 studs, so the server may refuse anything much further out'
	})
	AutoFarmer:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(6)
		end
	})
	Delay = AutoFarmer:CreateSlider({
		Name = 'Delay',
		Min = 0.05,
		Max = 3,
		Default = 0.15,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoFlora
	local Mode
	local Height
	local Speed
	local nextGlide = 0
	
	AutoFlora = vape.Categories.Kits:CreateModule({
		Name = 'AutoFlora',
		Function = function(callback)
			if callback then
				nextGlide = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'queen_bee' and tick() >= nextGlide and bedwars.AbilityController:canUseAbility('QUEEN_BEE_GLIDE', {disableBlockedAbilityAlert = true}) then
						local root = entitylib.character.RootPart
	
						if root.AssemblyLinearVelocity.Y <= -Speed.Value then
							local drop = Mode.Value == 'Void' and 2000 or Height.Value
							local ground = workspace:Raycast(root.Position, Vector3.new(0, -drop, 0), store.airRay)
	
							if not ground then
								nextGlide = tick() + 1
								bedwars.AbilityController:useAbility('QUEEN_BEE_GLIDE')
							end
						end
					end
					task.wait(0.05)
				until not AutoFlora.Enabled
			end
		end,
		Tooltip = 'Opens the glide the moment you drop with nothing under you'
	})
	
	Mode = AutoFlora:CreateDropdown({
		Name = 'Mode',
		List = {'Void', 'Any Drop'},
		Default = 'Void',
		Function = function(val)
			if Height then
				Height.Object.Visible = val == 'Any Drop'
			end
		end,
		Tooltip = 'Void - only when there is no floor at all under you\nAny Drop - also for long falls onto the map'
	})
	Height = AutoFlora:CreateSlider({
		Name = 'Ground check',
		Min = 5,
		Max = 200,
		Default = 40,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Speed = AutoFlora:CreateSlider({
		Name = 'Fall speed',
		Min = 1,
		Max = 100,
		Default = 20,
		Tooltip = 'How fast you have to be dropping before it glides'
	})
	
end)

run(function()
	local AutoFreiya
	local Range
	local Stacks
	local Delay
	
	local cooldown = 0
	
	AutoFreiya = vape.Categories.Kits:CreateModule({
		Name = 'AutoFreiya',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'ice_queen' and tick() >= cooldown and bedwars.AbilityController:canUseAbility('ice_queen', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Targetable and (v.Character:GetAttribute('IceQueenStacks') or 0) >= Stacks.Value and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								cooldown = tick() + Delay.Value
								bedwars.AbilityController:useAbility('ice_queen')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFreiya.Enabled
			end
		end,
		Tooltip = 'Automatically detonates ice stacks once enemies are frozen enough'
	})
	
	Range = AutoFreiya:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoFreiya:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 100,
		Suffix = 'seconds'
	})
	Stacks = AutoFreiya:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Ice stacks an enemy needs before detonating'
	})
end)

run(function()
	local AutoGingerbread
	local Range
	local Delay
	local Break
	local Place
	local PlaceDelay
	local Jump
	local Switch
	local OwnOnly
	local SuccessfulOnly
	
	local old
	local nextPlace = 0
	
	AutoGingerbread = vape.Categories.Kits:CreateModule({
		Name = 'AutoGingerbreadMan',
		Function = function(callback)
			if callback then
				nextPlace = 0
				AutoGingerbread:Clean(runService.Heartbeat:Connect(function()
					if Place.Enabled and entitylib.isAlive and store.equippedKit == 'gingerbread_man' and tick() >= nextPlace and canPlace() and getItem('gumdrop_bounce_pad') then
						local pos = roundPos(entitylib.character.RootPart.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
						if not getPlacedBlock(pos) then
							nextPlace = tick() + math.max(PlaceDelay.Value, 1 / bedwars.SharedConstants.BLOCK_PLACE_CPS)
							bedwars.placeBlock(pos, 'gumdrop_bounce_pad')
						end
					end
				end))
	
				old = bedwars.LaunchPadController.attemptLaunch
				bedwars.LaunchPadController.attemptLaunch = function(self, block, ...)
					local lastLaunch = self and self.lastLaunch or 0
					local call = old(self, block, ...)
	
					if not SuccessfulOnly.Enabled or self and self.lastLaunch and self.lastLaunch ~= lastLaunch then
						if Break.Enabled and entitylib.isAlive and store.equippedKit == 'gingerbread_man' and block and block:IsA('BasePart') and (not OwnOnly.Enabled or block:GetAttribute('PlacedByUserId') == lplr.UserId) and (block.Position - entitylib.character.RootPart.Position).Magnitude <= Range.Value then
							task.delay(Delay.Value, function()
								if AutoGingerbread.Enabled and block.Parent then
									if Switch.Enabled then
										local itemmeta = bedwars.ItemMeta[block.Name]
										local breaktype = itemmeta and itemmeta.block and itemmeta.block.breakType
										local tool = breaktype and store.tools[breaktype] or store.tools.sword
										local slot = tool and getHotbar(tool.tool)
										if slot then
											hotbarSwitch(slot)
										elseif tool then
											switchItem(tool.tool)
										end
									end
									bedwars.breakBlock(block, false, nil, nil, Switch.Enabled)
								end
							end)
						end
	
						if Jump.Enabled and entitylib.isAlive then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
					return call
				end
			else
				bedwars.LaunchPadController.attemptLaunch = old
			end
		end,
		Tooltip = 'Automatically handles Gingerbread Man launch pads.'
	})
	
	Place = AutoGingerbread:CreateToggle({
		Name = 'Place pads',
		Function = function(call)
			if PlaceDelay then
				PlaceDelay.Object.Visible = call
			end
		end,
		Tooltip = 'Drops a bounce pad into the cell below you whenever it is empty, so a jump lands you straight back onto one',
		Default = true
	})
	PlaceDelay = AutoGingerbread:CreateSlider({
		Name = 'Place delay',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'sec' or 'secs'
		end
	})
	Break = AutoGingerbread:CreateToggle({
		Name = 'Break launch pad',
		Function = function(call)
			if Range then
				Range.Object.Visible = call
				Delay.Object.Visible = call
				Switch.Object.Visible = call
				OwnOnly.Object.Visible = call
			end
		end,
		Default = true
	})
	Jump = AutoGingerbread:CreateToggle({Name = 'Jump after launch'})
	
	Switch = AutoGingerbread:CreateToggle({
		Name = 'Legit switch',
		Darker = true
	})
	OwnOnly = AutoGingerbread:CreateToggle({
		Name = 'Own pads only',
		Default = true,
		Darker = true
	})
	SuccessfulOnly = AutoGingerbread:CreateToggle({
		Name = 'Successful launch only',
		Default = true
	})
	Range = AutoGingerbread:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoGingerbread:CreateSlider({
		Name = 'Break delay',
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoGrim
	local Range
	local Health
	local Delay
	
	local Legit = getFunctionRange(bedwars.GrimReaperController.registerSoulInteractions) or 0
	
	AutoGrim = vape.Categories.Kits:CreateModule({
		Name = 'AutoGrim',
		Function = function(callback)
			if callback then
				local souls = collection(bedwars.GrimReaperController.soulsByPosition, AutoGrim)
				local cooldown = 0
	
				repeat
					if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') * (Health.Value / 100)) and not lplr.Character:GetAttribute('GrimReaperChannel') and (Delay.Value <= 0 or tick() - cooldown >= Delay.Value) then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in souls do
							if (localPosition - v.Position).Magnitude <= Range.Value then
								bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
									secret = v:GetAttribute('GrimReaperSoulSecret')
								})
								cooldown = tick()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoGrim.Enabled
			end
		end,
		Tooltip = 'Automatically consumes nearby souls when your health drops low'
	})
	
	Range = AutoGrim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoGrim:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Health = AutoGrim:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 25,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Only eats a soul once your health drops to this share of your maximum'
	})
	Delay = AutoGrim:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
end)

run(function()
	local AutoGrove
	local Delay
	local nextWater = 0
	
	AutoGrove = vape.Categories.Kits:CreateModule({
		Name = 'AutoGrove',
		Function = function(callback)
			if callback then
				nextWater = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'spirit_gardener' and tick() >= nextWater and bedwars.AbilityController:canUseAbility('spirit_gardener_water', {disableBlockedAbilityAlert = true}) then
						nextWater = tick() + Delay.Value
						bedwars.AbilityController:useAbility('spirit_gardener_water')
					end
					task.wait(0.1)
				until not AutoGrove.Enabled
			end
		end,
		Tooltip = 'Automatically feeds spirit energy to your flowers so they never wither'
	})
	
	Delay = AutoGrove:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 20,
		Default = 3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoHannah
	local Targets
	local Sort
	local Range
	local AuraTarget
	local attempted = setmetatable({}, {__mode = 'k'})
	
	AutoHannah = vape.Categories.Kits:CreateModule({
		Name = 'AutoHannah',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'hannah' and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'grounded') and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'frosted') then
						local threshold = bedwars.BalanceFile.HANNAH_BASE_EXECUTE_THRESHOLD + (bedwars.BalanceFile.HANNAH_MAX_COMBO * bedwars.BalanceFile.HANNAH_COMBO_EXECUTE_BOOST)
	
						for _, v in entitylib.AllPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Sort = sortmethods[Sort.Value]
						}) do
							if v.Character:HasTag('HannahExecuteInteraction') and v.Health <= v.MaxHealth * threshold and (not AuraTarget.Enabled or (targetinfo.Targets[v] or 0) > tick()) and (not attempted[v.Character] or tick() - attempted[v.Character] >= 0.3) then
								attempted[v.Character] = tick()
	
								if bedwars.Handler:Get('HannahPromptTrigger'):Fire('CallServer', {
									user = lplr,
									victimEntity = v.Character
								}) then
									local billboard = v.Character:FindFirstChild('Hannah Execution Icon')
									if billboard then
										billboard:Destroy()
									end
								end
	
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoHannah.Enabled
				table.clear(attempted)
			end
		end,
		Tooltip = 'Automatically executes low health players with Hannah.'
	})
	
	Targets = AutoHannah:CreateTargets({Players = true})
	local methods = {'Health', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = AutoHannah:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Health'
	})
	Range = AutoHannah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AuraTarget = AutoHannah:CreateToggle({
		Name = 'Only killaura target',
		Tooltip = 'Only executes targets that are being attacked by killaura'
	})
end)

run(function()
	local AutoHephaestus
	local Summon
	local lastRepair, lastSummon = 0, 0
	
	AutoHephaestus = vape.Categories.Kits:CreateModule({
		Name = 'AutoHephaestus',
		Function = function(callback)
			if callback then
				AutoHephaestus:Clean(runService.Heartbeat:Connect(function()
					if store.equippedKit ~= 'tinker' then return end
	
					if bedwars.TinkerKitController.mounted then
						if tick() >= lastRepair and bedwars.AbilityController:canUseAbility('tinker_self_repair', {disableBlockedAbilityAlert = true}) and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 1 then
							lastRepair = tick() + 0.5
							bedwars.AbilityController:useAbility('tinker_self_repair')
						end
					elseif Summon.Enabled and tick() >= lastSummon and bedwars.AbilityController:canUseAbility('tinker_summon', {disableBlockedAbilityAlert = true}) then
						lastSummon = tick() + 1
						bedwars.AbilityController:useAbility('tinker_summon')
					end
				end))
			end
		end,
		Tooltip = 'Automatically repairs your Tinker machine whenever the self repair ability is available'
	})
	
	Summon = AutoHephaestus:CreateToggle({
		Name = 'Summon tinker',
		Tooltip = 'Calls the machine back whenever you are not mounted on it'
	})
end)

run(function()
	local AutoKaida
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local Spell
	local SpellMode
	local SpellCharge
	local SpellRange
	local Swing
	local Limit
	local Mouse
	local GUI
	
	local casting = 0
	
	local function getClaw()
		if Limit.Enabled then
			return store.hand.tool and bedwars.IsItemClaw(store.hand.tool.Name) and store.hand or nil
		end
	
		for _, v in store.inventory.inventory.items do
			if bedwars.IsItemClaw(v.itemType) then
				return v
			end
		end
		return nil
	end
	
	local function castSpell()
		local localPosition = entitylib.character.RootPart.Position
		local target
		if SpellMode.Value == 'Camera' then
			local point = bedwars.AbilityIndicatorUtil:calculateBlockTargetPoint(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector, 300, nil, {allowArenaBarrierTarget = false})
			target = point and (point - localPosition).Magnitude <= SpellRange.Value and point or nil
		else
			local ent = entitylib.EntityPosition({
				Range = SpellRange.Value,
				Part = 'RootPart',
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled,
				Priority = Targets.Priority.Value,
				Sort = sortmethods[Sort.Value]
			})
			if ent then
				local point = bedwars.AbilityIndicatorUtil:calculateBlockTargetPoint(ent.RootPart.Position + Vector3.new(0, 3, 0), Vector3.new(0, -1, 0), 30, nil, {allowArenaBarrierTarget = false})
				target = point and (point - localPosition).Magnitude <= SpellRange.Value and point or ent.RootPart.Position
			end
		end
		if not target or not bedwars.AbilityController:canUseAbility('summoner_start_charging', {disableBlockedAbilityAlert = true}) then return end
	
		casting = tick() + 6
		bedwars.AbilityController:useAbility('summoner_start_charging', nil, {targetPosition = target})
	
		local level = bedwars.SummonerUtil.summoner_getPlayerSpellLevel(lplr) or 1
		local charge = math.max(bedwars.SummonerUtil.summoner_getTotalCastTimeRequired(level) * (SpellCharge.Value / 100), bedwars.SummonerKitBalance.SPELL_MINIMUM_CAST_TIME)
		local deadline = tick() + charge
		repeat task.wait() until tick() >= deadline or not AutoKaida.Enabled or not entitylib.isAlive or not bedwars.SummonerKitController:isPlayerCastingSpell(lplr)
	
		if AutoKaida.Enabled and entitylib.isAlive and bedwars.SummonerKitController:isPlayerCastingSpell(lplr) then
			bedwars.AbilityController:useAbility('summoner_finish_charging')
		end
		casting = 0
	end
	
	AutoKaida = vape.Categories.Kits:CreateModule({
		Name = 'AutoKaida',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'summoner' then
						if Spell.Enabled and tick() > casting and not bedwars.SummonerKitController:isPlayerCastingSpell(lplr) then
							task.spawn(castSpell)
						end
	
						local claw = (not Mouse.Enabled or inputService:IsMouseButtonPressed(0)) and (not GUI.Enabled or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)) and getClaw()
						local ent = claw and (workspace:GetServerTimeNow() - bedwars.SummonerClawHandController.lastAttackTime) > bedwars.SummonerKitBalance.CLAW_COOLDOWN and (Swing.Enabled or not bedwars.SummonerKitController:isPlayerCastingSpell(lplr)) and entitylib.EntityPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Sort = sortmethods[Sort.Value]
						})
	
						if ent then
							local selfpos = entitylib.character.RootPart.Position
							local delta = ent.RootPart.Position - selfpos
							local dir = CFrame.lookAt(selfpos, ent.RootPart.Position).LookVector
							targetinfo.Targets[ent] = tick() + 1
							switchItem(claw.tool, 0)
							if delta.Magnitude <= AttackRange.Value then
								bedwars.Handler:Get('SummonerClawAttackRequest'):Fire(nil, {
									position = selfpos + dir * math.max(delta.Magnitude - 16.399, 0),
									direction = dir,
									clientTime = workspace:GetServerTimeNow()
								})
							end
							bedwars.SummonerClawHandController.lastAttackTime = workspace:GetServerTimeNow()
							bedwars.SummonerClawController:clawAttack(lplr, selfpos, dir, claw.tool.Name)
						end
					end
	
					task.wait(0.1)
				until not AutoKaida.Enabled
			else
				casting = 0
			end
		end,
		Tooltip = 'Automatically attacks with the Kaida claw and casts her summon circle'
	})
	
	Targets = AutoKaida:CreateTargets({Players = true})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = AutoKaida:CreateDropdown({
		Name = 'Target mode',
		List = methods
	})
	SwingRange = AutoKaida:CreateSlider({
		Name = 'Swing Range',
		Min = 1,
		Max = 32,
		Default = 32,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AttackRange = AutoKaida:CreateSlider({
		Name = 'Attack Range',
		Min = 1,
		Max = 32,
		Default = 32,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Spell = AutoKaida:CreateToggle({
		Name = 'Auto summon',
		Function = function(callback)
			if SpellMode then
				SpellMode.Object.Visible = callback
				SpellCharge.Object.Visible = callback
				SpellRange.Object.Visible = callback
			end
		end,
		Tooltip = 'Charges and drops the summon circle on its own'
	})
	SpellMode = AutoKaida:CreateDropdown({
		Name = 'Summon at',
		List = {'Target', 'Camera'},
		Darker = true,
		Visible = false,
		Tooltip = 'Target drops the circle on the closest enemy, Camera drops it where you are looking'
	})
	SpellCharge = AutoKaida:CreateSlider({
		Name = 'Charge',
		Min = 1,
		Max = 100,
		Default = 100,
		Darker = true,
		Visible = false,
		Suffix = '%',
		Tooltip = 'How far to charge before releasing, 100% is the full radius for your spell level'
	})
	SpellRange = AutoKaida:CreateSlider({
		Name = 'Summon Range',
		Min = 1,
		Max = 39,
		Default = 39,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'The game refuses anything past 39 studs'
	})
	Swing = AutoKaida:CreateToggle({
		Name = 'Swing during ability',
		Default = true,
		Tooltip = 'Continue claw attacks while the ability is charging'
	})
	Limit = AutoKaida:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks while the claw is held'
	})
	Mouse = AutoKaida:CreateToggle({Name = 'Require mouse down'})
	GUI = AutoKaida:CreateToggle({Name = 'GUI check'})
end)

run(function()
	local AutoKaliyah
	local Range
	local Stacks
	local Delay
	local NoSlow
	
	local Legit = getFunctionRange(bedwars.DragonSlayerController.hasEligiblePunchTarget) or 14.4
	local modifier, old
	local noSlowUntil = 0
	
	local function punch()
		if NoSlow.Enabled then
			if not old then
				modifier = bedwars.SprintController:getMovementStatusModifier()
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if NoSlow.Enabled and tick() < noSlowUntil and tab and tab.moveSpeedMultiplier == 0 then
						tab.moveSpeedMultiplier = 1
					end
					return old(self, tab)
				end
	
				AutoKaliyah:Clean(function()
					modifier.addModifier = old
					modifier, old = nil, nil
					noSlowUntil = 0
				end)
			end
			noSlowUntil = math.max(noSlowUntil, tick() + Delay.Value + 0.1)
		end
	
		task.wait(Delay.Value)
		bedwars.AbilityController:useAbility('dragon_slayer_punch')
	end
	
	AutoKaliyah = vape.Categories.Kits:CreateModule({
		Name = 'AutoKaliyah',
		Function = function(call)
			if call then
				repeat
					if entitylib.isAlive and store.equippedKit == 'dragon_slayer' and bedwars.AbilityController:canUseAbility('dragon_slayer_punch', {disableBlockedAbilityAlert = true}) then
						local localPosition = entitylib.character.RootPart.Position
						for i2, v2 in bedwars.DragonSlayerController.dragonEmblems do
							if v2.stackCount >= Stacks.Value and i2.PrimaryPart and (i2.PrimaryPart.Position - localPosition).Magnitude <= Range.Value then
								punch()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoKaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "punch" ability from kaliyah'
	})
	
	NoSlow = AutoKaliyah:CreateToggle({
		Name = 'No Slow',
		Default = true,
		Tooltip = 'Prevents you from being slowed down after using the "Punch" ability'
	})
	Range = AutoKaliyah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 18,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoKaliyah:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Stacks = AutoKaliyah:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 3,
		Default = 1,
		Suffix = function(val)
			return val <= 1 and 'stack' or 'stacks'
		end,
		Tooltip = 'How many emblems a target needs before the punch fires, 3 stacks deals 25 damage against a wall instead of 10'
	})
	Delay = AutoKaliyah:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)

run(function()
	local AutoKit
	local Legit
	local Toggles = {}
	
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if (vape.Modules.InfiniteFly or {}).Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or (v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true))
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Handler:Get('ConsumeBattery'):Fire('SendToServer', {batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			kitCollection('bee', function(v)
				bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		bigman = function()
			kitCollection('treeOrb', function(v)
				if bedwars.Handler:Get('ConsumeTreeOrb'):Fire('CallServer', {treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
					v:Destroy()
				end
			end, 12, false)
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
				})
	
				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.AssemblyLinearVelocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end
	
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...
				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false)
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Handler:Get('RequestDragonPunch'):Fire('SendToServer', {
					target = v
				})
			end, 18, true)
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Handler:Get('HarvestCrop'):Fire('CallServer', {position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.AudioManager:playAudio(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
			end
	
			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false)
					end
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Handler:Get('HannahPromptTrigger'):Fire('CallServer', {
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')
	
				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		jailor = function()
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, 20, false)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end
	
				if ent and getItem('guitar') then
					bedwars.Handler:Get('GuitarHeal'):Fire('SendToServer', {
						healTarget = ent.Character
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			kitCollection('hidden-metal', function(v)
				bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
					id = v:GetAttribute('Id')
				})
			end, 20, false)
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Handler:Get('DestroyPetrifiedPlayer'):Fire('SendToServer', {
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, 6, true)
		end,
		pinata = function()
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Handler:Get('DepositCoins'):Fire('CallServer', v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		star_collector = function()
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, 20, false)
		end,
		summoner = function()
			repeat
				local plr = entitylib.EntityPosition({
					Range = 31,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})
	
				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)
	
					bedwars.Handler:Get('SummonerClawAttackRequest'):Fire('SendToServer', {
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
	
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Handler:Get('DragonFlap'):Fire('CallServer') then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
	
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
	
			repeat
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})
	
					if plr then
						bedwars.Handler:Get('DragonBreath'):Fire('SendToServer', {
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		warlock = function()
			local lastTarget
			repeat
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = true
					})
	
					if plr and plr.Character ~= lastTarget then
						if not bedwars.Handler:Get('WarlockLinkTarget'):Fire('CallServer', {
							target = plr.Character
						}) then
							plr = nil
						end
					end
	
					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		wizard = function()
			repeat
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
					local plr = entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})
	
					if plr then
						bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
					end
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end
	}
	
	AutoKit = vape.Categories.Kits:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local function kitName(kit)
		local meta = bedwars.BedwarsKitMeta[kit]
		return meta and meta.name or kit
	end
	
	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return kitName(a) < kitName(b)
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = kitName(v),
			Default = true
		})
	end
end)

run(function()
	local AutoKrystal
	
	local function getBed()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude <= 22 and not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				return v
			end
		end
		return
	end
	
	AutoKrystal = vape.Categories.Kits:CreateModule({
		Name = 'AutoKrystal',
		Function = function(callback)
			if callback then
				repeat
					local bed = entitylib.isAlive and store.equippedKit == 'glacial_skater' and bedwars.AbilityController:canUseAbility('skating_freeze', {disableBlockedAbilityAlert = true}) and getBed()
					if bed then
						for _, v in store.blocks do
							if (bed.Position - v.Position).Magnitude <= 20 and v:GetAttribute('PlacedByUserId') then
								bedwars.AbilityController:useAbility('skating_freeze')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoKrystal.Enabled
			end
		end,
		Tooltip = 'Automatically uses freeze ability when near\nopponent\'s bed defense.'
	})
end)

run(function()
	local AutoLani
	local Delay
	local UseEnemy
	local Enemy
	local Player
	
	local Request = bedwars.Handler:Get('PaladinAbilityRequest')
	
	AutoLani = vape.Categories.Kits:CreateModule({
		Name = 'AutoLani',
		Function = function(call)
			if call then
				local oldstart
	
				repeat
					local start = lplr:GetAttribute('PaladinStartTime')
					if oldstart and oldstart ~= start then
						local player = UseEnemy.Enabled and playersService:FindFirstChild(Enemy.Value) or not UseEnemy.Enabled and playersService:FindFirstChild(Player.Value) or nil
						if player then
							task.delay(Delay.Value, function()
								Request:Fire('SendToServer', {target = player})
							end)
						end
					end
					oldstart = start
					task.wait(0.1)
				until not AutoLani.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "scepter of light" ability'
	})
	
	local friends, enemies = {'None'}, {'None'}
	
	local function addConnection(plr, connected)
		local friendly = plr:GetAttribute('Team') == lplr:GetAttribute('Team')
	
		if not connected then
			vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
				addConnection(plr, true)
			end))
		end
	
		if friendly and not table.find(friends, plr.Name) then
			table.insert(friends, plr.Name)
			Player:Change(friends)
		elseif not friendly and plr.Team and plr.Team.Name ~= 'Spectators' and not table.find(enemies, plr.Name) then
			table.insert(enemies, plr.Name)
			Enemy:Change(enemies)
		end
	end
	
	Player = AutoLani:CreateDropdown({
		Name = 'Selected Player',
		List = {},
		Tooltip = 'Player to use the ability on'
	})
	Enemy = AutoLani:CreateDropdown({
		Name = 'Selected Enemy',
		List = {},
		Visible = false,
		Tooltip = 'Target to use the ability on'
	})
	UseEnemy = AutoLani:CreateToggle({
		Name = 'Use enemy',
		Function = function(call)
			Enemy.Object.Visible = call
			Player.Object.Visible = not call
		end,
		Tooltip = 'Uses the ability on other people instead of your teammates'
	})
	Delay = AutoLani:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 20,
		Default = 5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end,
		Tooltip = 'Delay between triggers'
	})
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)

run(function()
	local AutoLasso
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0
	
	local function throwLasso()
		local item = getItem('lasso')
		local source = item and bedwars.ItemMeta.lasso.projectileSource or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end
	
		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'lasso', source.projectileType('lasso'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end
	
	AutoLasso = vape.Categories.Kits:CreateModule({
		Name = 'AutoLasso',
		Function = function(callback)
			if callback then
				nextFire = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'cowgirl' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						throwLasso()
					end
					task.wait(0.1)
				until not AutoLasso.Enabled
			end
		end,
		Tooltip = 'Automatically throws Lassy\'s lasso at whoever you\'re meleeing'
	})
	
	Targets = AutoLasso:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoLasso:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoLasso:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoLasso:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoLumen
	local Targets
	local Range
	local FullCharge
	local Delay
	
	local Balance = bedwars.LumenBalance or {MIN_CHARGE_TIME = 0.65, MAX_CHARGE_TIME = 1.25}
	local Sword = 'light_sword'
	local cooldown = 0
	
	local function chargedSwing()
		local charge = bedwars.SwordChargeController
		if charge:getChargeState() ~= bedwars.ChargeState.Idle then return end
	
		charge:startCharging(Sword)
		local started = charge:getChargeStartTime()
		if started == 0 then return end
	
		local itemmeta = bedwars.ItemMeta[Sword]
		local charged = itemmeta and itemmeta.sword and itemmeta.sword.chargedAttack
		local target = (FullCharge.Enabled and (charged and charged.maxChargeTimeSec or Balance.MAX_CHARGE_TIME) or (charged and charged.minChargeTimeSec or Balance.MIN_CHARGE_TIME)) + 0.05
		repeat task.wait() until not AutoLumen.Enabled or not entitylib.isAlive or (tick() - started) >= target
	
		local chargeTime = tick() - started
		charge:stopCharging(Sword)
		if not AutoLumen.Enabled or not entitylib.isAlive then return end
	
		local tool = store.hand.tool
		if not tool or tool.Name ~= Sword then return end
	
		local charged = bedwars.ItemMeta[Sword].sword.chargedAttack
		if not (charged.skipSwingDamage and chargeTime > (charged.minChargeTimeSec or Balance.MIN_CHARGE_TIME)) then
			bedwars.SwordController:swingSwordAtMouse(chargeTime)
		end
	
		bedwars.SyncEvents.SwordChargedSwing:fire(lplr, tool, {chargeTime = chargeTime})
		cooldown = tick() + Delay.Value
	end
	
	AutoLumen = vape.Categories.Kits:CreateModule({
		Name = 'AutoLumen',
		Function = function(callback)
			if callback then
				cooldown = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'lumen' and store.hand.tool and store.hand.tool.Name == Sword and tick() >= cooldown then
						local target = entitylib.EntityMouse({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if target then
							chargedSwing()
						end
					end
					task.wait(0.1)
				until not AutoLumen.Enabled
			end
		end,
		Tooltip = 'Charges the sword of light and releases a wave whenever an enemy is in front of you, Killaura skips this sword because it has a charged attack'
	})
	
	Targets = AutoLumen:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoLumen:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FullCharge = AutoLumen:CreateToggle({
		Name = 'Full charge',
		Default = true,
		Tooltip = 'Holds the swing to the maximum charge, an upgraded lumen only fires the multi beam at full charge'
	})
	Delay = AutoLumen:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)

run(function()
	local AutoMarina
	local Range
	
	AutoMarina = vape.Categories.Kits:CreateModule({
		Name = 'AutoMarina',
		Function = function(call)
			if call then
				local jellies = collection('jellyfish', AutoMarina, function(tab, obj)
					task.delay(0, function()
						if obj:GetAttribute('PlacedByUserId') == lplr.UserId then
							table.insert(tab, obj)
						end
					end)
				end)
	
				repeat
					if entitylib.isAlive and bedwars.AbilityController:canUseAbility('electrify_jellyfish', {disableBlockedAbilityAlert = true}) then
						for _, v in jellies do
							if v.PrimaryPart and entitylib.EntityPosition({
								Origin = v.PrimaryPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							}) then
								bedwars.AbilityController:useAbility('electrify_jellyfish')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoMarina.Enabled
			end
		end,
		Tooltip = 'Automatically uses "electrify" ability when enemies are near jellies.'
	})
	
	Range = AutoMarina:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 65,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoMarrow
	local Mode
	local Targets
	local Range
	local Health
	
	AutoMarrow = vape.Categories.Kits:CreateModule({
		Name = 'AutoMarrow',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'skeleton' and bedwars.AbilityController:canUseAbility('skeleton_ability', {disableBlockedAbilityAlert = true}) then
						local humanoid = entitylib.character.Humanoid
						local low = humanoid.Health <= (humanoid.MaxHealth * (Health.Value / 100))
						local near = #entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						}) > 0
	
						if (Mode.Value == 'Low Health' and low) or (Mode.Value == 'Enemy Near' and near) or (Mode.Value == 'Both' and (low or near)) then
							bedwars.AbilityController:useAbility('skeleton_ability')
						end
					end
					task.wait(0.1)
				until not AutoMarrow.Enabled
			end
		end,
		Tooltip = 'Automatically drops Toxic Escape clouds when you are in trouble'
	})
	
	Mode = AutoMarrow:CreateDropdown({
		Name = 'Mode',
		List = {'Both', 'Low Health', 'Enemy Near'},
		Default = 'Both'
	})
	Targets = AutoMarrow:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = AutoMarrow:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Health = AutoMarrow:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 45,
		Suffix = '%',
		Tooltip = 'Drops the clouds once you fall under this'
	})
	
end)

run(function()
	local AutoMartin
	local Targets
	local Range
	local Delay
	
	local cooldown = 0
	
	AutoMartin = vape.Categories.Kits:CreateModule({
		Name = 'AutoMartin',
		Function = function(callback)
			if callback then
				cooldown = 0
	
				repeat
					if tick() >= cooldown and entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Sort = sortmethods.Distance
					}) and bedwars.AbilityController:canUseAbility('cactus_fire', {disableBlockedAbilityAlert = true}) then
						cooldown = tick() + Delay.Value
						bedwars.AbilityController:useAbility('cactus_fire')
					end
					task.wait(0.1)
				until not AutoMartin.Enabled
			end
		end,
		Tooltip = 'Automatically uses "Wild growth" ability when within range.'
	})
	
	Targets = AutoMartin:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoMartin:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 0 and 'stud' or 'studs'
		end
	})
	Delay = AutoMartin:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)

run(function()
	local AutoMelody
	local Range
	local SelfHeal
	local TeammateHeal
	local UseHotbar
	local SwitchBack
	local nextHeal = 0
	
	AutoMelody = vape.Categories.Kits:CreateModule({
		Name = 'AutoMelody',
		Function = function(callback)
			if callback then
				nextHeal = 0
	
				repeat
					local hp, target = math.huge, nil
					if entitylib.isAlive and tick() >= nextHeal then
						local localPosition = entitylib.character.RootPart.Position
	
						if SelfHeal.Enabled and entitylib.character.Health < entitylib.character.MaxHealth then
							hp, target = entitylib.character.Health, entitylib.character
						end
	
						if TeammateHeal.Enabled then
							for _, v in entitylib.List do
								if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') and v.Health > 0 and v.Health < v.MaxHealth and v.Health < hp and (localPosition - v.RootPart.Position).Magnitude <= Range.Value then
									hp, target = v.Health, v
								end
							end
						end
					end
	
					local guitar = target and getItem('guitar')
					if guitar then
						local previousSlot, previousTool = store.inventory.hotbarSlot, store.hand.tool
	
						if UseHotbar.Enabled then
							local slot = getHotbar(guitar.tool)
							if slot then
								hotbarSwitch(slot)
							end
						end
	
						nextHeal = tick() + bedwars.MelodyKitBalance.HEAL_COOLDOWN
						bedwars.Handler:Get('PlayGuitar'):Fire('SendToServer', {
							healTarget = target.Character
						})
	
						if UseHotbar.Enabled and SwitchBack.Enabled then
							if previousSlot and previousSlot ~= store.inventory.hotbarSlot then
								hotbarSwitch(previousSlot)
							elseif previousTool then
								switchItem(previousTool)
							end
						end
					end
					task.wait(0.1)
				until not AutoMelody.Enabled
				bedwars.Handler:Get('StopPlayingGuitar'):Fire('SendToServer')
			end
		end,
		Tooltip = 'Automatically uses the guitar to heal ur teammates/urself'
	})
	
	SelfHeal = AutoMelody:CreateToggle({
		Name = 'Self Heal',
		Default = true
	})
	TeammateHeal = AutoMelody:CreateToggle({
		Name = 'Teammate Heal',
		Default = true
	})
	Range = AutoMelody:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 51,
		Default = 51,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'The guitar reaches 51 studs, which is what this defaults to'
	})
	UseHotbar = AutoMelody:CreateToggle({
		Name = 'Use hotbar',
		Function = function(callback)
			if SwitchBack then
				SwitchBack.Object.Visible = callback
			end
		end,
		Tooltip = 'Visibly swaps onto the guitar slot before healing instead of playing it silently'
	})
	SwitchBack = AutoMelody:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Returns to whatever you were holding after the heal'
	})
end)

run(function()
	local AutoMetal
	local Limit
	local StreamerMode
	local Duration
	local Range
	local Animation
	
	local Legit = getFunctionRange(bedwars.HiddenMetalController.onKitLocalActivated) or 0
	local cooldowns = {}
	
	AutoMetal = vape.Categories.Kits:CreateModule({
		Name = 'AutoMetal',
		Function = function(call)
			if call then
				AutoMetal:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if StreamerMode.Enabled and prompt.Name == 'hidden-metal-prompt' and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
						task.wait(0.1)
						prompt:InputHoldBegin()
					end
				end))
	
				repeat
					if not StreamerMode.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('hidden-metal') do
							if tick() > (cooldowns[v] or 0) and (localPosition - v.Part.Position).Magnitude <= Range.Value and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
								if Duration.Value > 0 then
									task.wait(Duration.Value)
								end
	
								if (localPosition - v.Part.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.SHOVEL_DIG)
										bedwars.AudioManager:playAudio(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
									end
	
									bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
										id = v:GetAttribute('Id')
									})
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoMetal.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically uses the metal kit'
	})
	
	Limit = AutoMetal:CreateToggle({Name = 'Limit to item'})
	
	StreamerMode = AutoMetal:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Duration then
				Duration.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Actually does the metal prompt thing for you'
	})
	Animation = AutoMetal:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the metal collect animation'
	})
	Range = AutoMetal:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = Legit,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoMetal:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Duration = AutoMetal:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 5,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoMushroom
	local Ingredient
	local Delay
	local nextAdd = 0
	
	local ingredients = {
		Mushrooms = 'alchemist_add_mushrooms',
		Flowers = 'alchemist_add_flower',
		Thorns = 'alchemist_add_thorns'
	}
	
	AutoMushroom = vape.Categories.Kits:CreateModule({
		Name = 'AutoMushroom',
		Function = function(callback)
			if callback then
				nextAdd = 0
	
				repeat
					local ability = ingredients[Ingredient.Value]
					if entitylib.isAlive and store.equippedKit == 'alchemist' and tick() >= nextAdd and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
						nextAdd = tick() + Delay.Value
						bedwars.AbilityController:useAbility(ability)
					end
					task.wait(0.1)
				until not AutoMushroom.Enabled
			end
		end,
		Tooltip = 'Automatically tops the alchemist flask up with an ingredient'
	})
	
	Ingredient = AutoMushroom:CreateDropdown({
		Name = 'Ingredient',
		List = {'Mushrooms', 'Flowers', 'Thorns'}
	})
	Delay = AutoMushroom:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoNahila
	local Health
	local Range
	local Allies
	
	AutoNahila = vape.Categories.Kits:CreateModule({
		Name = 'AutoNahila',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'oasis' and bedwars.AbilityController:canUseAbility('oasis_heal_veil', {disableBlockedAbilityAlert = true}) then
						local character = entitylib.character
						local hurt = (character.Health / character.MaxHealth) <= (Health.Value / 100)
						if not hurt and Allies.Enabled then
							local origin = character.RootPart.Position
							for _, v in entitylib.List do
								if not v.Targetable and v.Player and v ~= character and (v.RootPart.Position - origin).Magnitude <= Range.Value and (v.Health / v.MaxHealth) <= (Health.Value / 100) then
									hurt = true
									break
								end
							end
						end
	
						if hurt then
							bedwars.AbilityController:useAbility('oasis_heal_veil')
						end
					end
					task.wait(0.1)
				until not AutoNahila.Enabled
			end
		end,
		Tooltip = 'Automatically drops the heal veil when you or a teammate is hurt'
	})
	
	Health = AutoNahila:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Heals at or below this much health'
	})
	Allies = AutoNahila:CreateToggle({
		Name = 'Heal teammates',
		Default = true
	})
	Range = AutoNahila:CreateSlider({
		Name = 'Ally range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoNazar
	local Consume
	local Health
	local Force
	local Empower
	local Range
	local empowered = false
	
	AutoNazar = vape.Categories.Kits:CreateModule({
		Name = 'AutoNazar',
		Function = function(callback)
			if callback then
				empowered = false
				AutoNazar:Clean(lplr.CharacterAdded:Connect(function()
					empowered = false
				end))
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'nazar' then
						local character = entitylib.character
						local lifeForce = lplr:GetAttribute('LifeForce') or 0
						if Consume.Enabled and lifeForce >= Force.Value and (character.Health / character.MaxHealth) <= (Health.Value / 100) and bedwars.AbilityController:canUseAbility('consume_life_foce', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('consume_life_foce')
						end
	
						if Empower.Enabled then
							local wanted = entitylib.EntityPosition({
								Origin = character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							}) and true or false
							if wanted ~= empowered then
								local ability = wanted and 'enable_life_force_attack' or 'disable_life_force_attack'
								if bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
									bedwars.AbilityController:useAbility(ability)
									empowered = wanted
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoNazar.Enabled
			end
		end,
		Tooltip = 'Automatically spends life force to heal and empowers attacks near enemies'
	})
	
	Health = AutoNazar:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 70,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Consumes once your health drops below this'
	})
	Force = AutoNazar:CreateSlider({
		Name = 'Life force',
		Min = 1,
		Max = 150,
		Default = 35,
		Tooltip = 'Life force you need stored before consuming'
	})
	Range = AutoNazar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Consume = AutoNazar:CreateToggle({
		Name = 'Consume life force',
		Function = function(callback)
			Health.Object.Visible = callback
			Force.Object.Visible = callback
		end,
		Tooltip = 'Converts stored life force into health when hurt',
		Default = true
	})
	Empower = AutoNazar:CreateToggle({
		Name = 'Empower attacks',
		Function = function(callback)
			Range.Object.Visible = callback
		end,
		Tooltip = 'Enables empowered attacks while an enemy is close and disables them after',
		Default = true
	})
end)

run(function()
	local AutoNoelle
	local Notify
	local FrostySlime
	local HealSlime
	local StickySlime
	local VoidSlime
	local Limit
	
	local function getSlimes()
		local slimes = {}
		local folder = workspace:FindFirstChild('SlimeModelFolder')
		for _, v in folder and folder:GetChildren() or {} do
			local data = v:FindFirstChild('SlimeData')
			data = data and data.Value
	
			if data and data.Tamer.Value == lplr.UserId then
				table.insert(slimes, {
					Data = data,
					RootPart = v,
					Name = v.Name:gsub(`_{lplr.Name}`, ''):gsub('Slime', ' Slime')
				})
			end
		end
		return slimes
	end
	
	local function getPlayer(name)
		for _, v in playersService:GetPlayers() do
			if `{v.DisplayName} ({v.Name})` == name then
				return v
			end
		end
		return
	end
	
	AutoNoelle = vape.Categories.Kits:CreateModule({
		Name = 'AutoNoelle',
		Function = function(call)
			if call then
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'slime_tamer_flute') then
						for _, v in getSlimes() do
							local dropdown = AutoNoelle.Options[`{v.Name} Target`]
							local player = dropdown and getPlayer(dropdown.Value)
							if player and v.Data.Following.Value ~= player.UserId then
								bedwars.Handler:Get('RequestMoveSlime'):Fire('CallServerAsync', {
									slimeId = v.Data:GetAttribute('Id'),
									targetPlayerUserId = player.UserId
								}):andThen(function(suc)
									if suc then
										v.Data.Following.Value = player.UserId
	
										if Notify.Enabled then
											notif('AutoNoelle', `Directed {v.Name} to {player.DisplayName} ({player.Name})`, 5, 'info')
										end
									end
								end)
							end
						end
					end
					task.wait(0.5)
				until not AutoNoelle.Enabled
			end
		end,
		Tooltip = 'Automatically directs the slimes to the selected player\'s'
	})
	
	local friends = {'None'}
	
	local function addConnection(plr, connected)
		if not connected then
			vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
				addConnection(plr, true)
			end))
		end
	
		local name = `{plr.DisplayName} ({plr.Name})`
		if plr:GetAttribute('Team') == lplr:GetAttribute('Team') and not table.find(friends, name) then
			table.insert(friends, name)
			FrostySlime:Change(friends)
			HealSlime:Change(friends)
			StickySlime:Change(friends)
			VoidSlime:Change(friends)
		end
	end
	
	Notify = AutoNoelle:CreateToggle({Name = 'Notify on direct'})
	
	Limit = AutoNoelle:CreateToggle({Name = 'Limit to item'})
	
	FrostySlime = AutoNoelle:CreateDropdown({
		Name = 'Frosty Slime Target',
		List = {},
		Tooltip = 'Player to direct frost slimes to'
	})
	HealSlime = AutoNoelle:CreateDropdown({
		Name = 'Heal Slime Target',
		List = {},
		Tooltip = 'Player to direct heal slimes to'
	})
	StickySlime = AutoNoelle:CreateDropdown({
		Name = 'Sticky Slime Target',
		List = {},
		Tooltip = 'Player to direct sticky slimes to'
	})
	VoidSlime = AutoNoelle:CreateDropdown({
		Name = 'Void Slime Target',
		List = {},
		Tooltip = 'Player to direct void slimes to'
	})
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)

run(function()
	local AutoNyx
	local Targets
	
	AutoNyx = vape.Categories.Kits:CreateModule({
		Name = 'AutoNyx',
		Function = function(call)
			if call then
				AutoNyx:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.damageType == 0 and damageTable.fromEntity and damageTable.fromEntity.Name == lplr.Name and entitylib.EntityPosition({
						Range = 14.4,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value
					}) and bedwars.AbilityController:canUseAbility('midnight', {disableBlockedAbilityAlert = true}) then
						bedwars.AbilityController:useAbility('midnight')
					end
				end))
			end
		end,
		Tooltip = 'Automatically uses the "midnight" ability when meleeing a target'
	})
	
	Targets = AutoNyx:CreateTargets({
		Players = true,
		NPCs = false
	})
end)

run(function()
	local AutoPyro
	local Delay
	
	local list = {'Range', 'Heat', 'Power'}
	
	AutoPyro = vape.Categories.Kits:CreateModule({
		Name = 'AutoPyro',
		Function = function(callback)
			if callback then
				repeat
					local flamethrower = getItem('flamethrower')
					if flamethrower then
						for _, v in list do
							local upgrade = v:lower()
							local value = flamethrower.tool:GetAttribute(upgrade) or -1
							local nextUpgrade = AutoPyro.Options[`Buy {v}`].Enabled and value < 3 and bedwars.PyroUpgradeMeta[upgrade].tiers[value + 2]
							if nextUpgrade then
								local currency = getItem(nextUpgrade.currency)
								if currency and currency.amount >= nextUpgrade.price then
									bedwars.Handler:Get('UpgradeFlamethrower'):Fire('CallServer', upgrade)
									task.wait(Delay.Value)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoPyro.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades flamethrower'
	})
	
	Delay = AutoPyro:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds',
		Tooltip = 'Wait between each upgrade it buys'
	})
	for _, v in list do
		AutoPyro:CreateToggle({
			Name = `Buy {v}`,
			Default = true
		})
	end
end)

run(function()
	local AutoRagnar
	
	local function getBed()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude <= 22 and not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				return v
			end
		end
		return
	end
	
	AutoRagnar = vape.Categories.Kits:CreateModule({
		Name = 'AutoRagnar',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'berserker' and bedwars.AbilityController:canUseAbility('berserker_rage', {disableBlockedAbilityAlert = true}) and getBed() then
						bedwars.AbilityController:useAbility('berserker_rage')
					end
					task.wait(0.1)
				until not AutoRagnar.Enabled
			end
		end,
		Tooltip = 'Automatically uses "Berserker Rage" ability when near\nopponent\'s bed.'
	})
end)

run(function()
	local AutoRamil
	local Range
	local Sorts
	local Targets
	local UseTornado
	local TornadoRange
	
	AutoRamil = vape.Categories.Kits:CreateModule({
		Name = 'AutoRamil',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'airbender' then
						local localPosition = entitylib.character.RootPart.Position
						local ent = entitylib.EntityPosition({
							Origin = localPosition,
							Range = UseTornado.Enabled and TornadoRange.Value > Range.Value and TornadoRange.Value or Range.Value,
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Sort = sortmethods[Sorts.Value]
						})
						local mag = ent and (localPosition - ent.RootPart.Position).Magnitude or math.huge
						if mag <= Range.Value and bedwars.AbilityController:canUseAbility('airbender_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_tornado')
						end
	
						if UseTornado.Enabled and mag <= TornadoRange.Value and bedwars.AbilityController:canUseAbility('airbender_moving_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_moving_tornado')
						end
					end
					task.wait()
				until not AutoRamil.Enabled
			end
		end,
		Tooltip = 'Automatically use ramil abilities on certain conditions.'
	})
	
	Targets = AutoRamil:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	
	Sorts = AutoRamil:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Range = AutoRamil:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 25,
		Default = 25,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
	UseTornado = AutoRamil:CreateToggle({
		Name = 'Use Moving Tornado',
		Function = function(call)
			if TornadoRange then
				TornadoRange.Object.Visible = call
			end
		end
	})
	TornadoRange = AutoRamil:CreateSlider({
		Name = 'Tornado Range',
		Min = 1,
		Max = 35,
		Default = 25,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
end)

run(function()
	local AutoSheep
	local Delay
	local Range
	local Infinite
	
	AutoSheep = vape.Categories.Kits:CreateModule({
		Name = 'AutoSheepHerder',
		Function = function(callback)
			if callback then
				local tameSheep = bedwars.Client:GetNamespace('SheepHerder'):Get('TameSheep')
	
				repeat
					local model = workspace:FindFirstChild('SheepModel')
					if entitylib.isAlive and model then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in model:GetChildren() do
							if v.PrimaryPart and (Infinite.Enabled or (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value) then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
								tameSheep:SendToServer(v.SheepData.Value)
							end
						end
					end
					task.wait(0.1)
				until not AutoSheep.Enabled
			end
		end,
		Tooltip = 'Automatically tames sheep within range.'
	})
	
	Range = AutoSheep:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 200,
		Default = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Infinite = AutoSheep:CreateToggle({
		Name = 'Infinite range',
		Tooltip = 'Tames every sheep on the map, the server may still reject far ones'
	})
	Delay = AutoSheep:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)

run(function()
	local AutoShielderUlt
	local Range
	local Targets
	local Delay
	local nextUlt = 0
	
	AutoShielderUlt = vape.Categories.Kits:CreateModule({
		Name = 'AutoShielderUlt',
		Function = function(callback)
			if callback then
				nextUlt = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'shielder' and tick() >= nextUlt then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end
	
						if found >= Targets.Value then
							nextUlt = tick() + Delay.Value
							bedwars.InfernalShieldController:useUlt()
						end
					end
					task.wait(0.1)
				until not AutoShielderUlt.Enabled
			end
		end,
		Tooltip = 'Automatically slams the infernal shield once enough enemies are around you'
	})
	
	Range = AutoShielderUlt:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoShielderUlt:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before slamming'
	})
	Delay = AutoShielderUlt:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoSigrid
	local Combat
	local Targets
	local Range
	local nextSummon = 0
	
	AutoSigrid = vape.Categories.Kits:CreateModule({
		Name = 'AutoSigrid',
		Function = function(callback)
			if callback then
				nextSummon = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'elk_master' and tick() >= nextSummon and bedwars.AbilityController:canUseAbility('elk_summon', {disableBlockedAbilityAlert = true}) then
						local wanted = not Combat.Enabled
	
						if not wanted then
							wanted = #entitylib.AllPosition({
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled
							}) > 0
						end
	
						if wanted then
							nextSummon = tick() + 1
							bedwars.AbilityController:useAbility('elk_summon')
						end
					end
					task.wait(0.1)
				until not AutoSigrid.Enabled
			end
		end,
		Tooltip = 'Keeps the elk summoned so you are never caught on foot'
	})
	
	Combat = AutoSigrid:CreateToggle({
		Name = 'Only in combat',
		Function = function(callback)
			if Range then
				Range.Object.Visible = callback
				Targets.Object.Visible = callback
			end
		end,
		Tooltip = 'Waits until somebody is nearby instead of resummoning on cooldown'
	})
	Targets = AutoSigrid:CreateTargets({
		Players = true,
		NPCs = true,
		Visible = false
	})
	Range = AutoSigrid:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 40,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	
end)

run(function()
	local AutoSilas
	local SwapAura
	local PressAttack
	local Range
	local aura = ''
	
	local function getHurtAlly(origin)
		for _, v in entitylib.List do
			if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') and v.Health < v.MaxHealth and (v.RootPart.Position - origin).Magnitude <= Range.Value then
				return v
			end
		end
		return nil
	end
	
	AutoSilas = vape.Categories.Kits:CreateModule({
		Name = 'AutoSilas',
		Function = function(callback)
			if callback then
				aura = ''
				AutoSilas:Clean(bedwars.Handler:Get('UpdateRebellionAura').Remote:Connect(function(data)
					if data.player == lplr then
						aura = data.newAura
					end
				end))
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'rebellion_leader' then
						local origin = entitylib.character.RootPart.Position
						local enemy = entitylib.EntityPosition({
							Origin = origin,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})
	
						if PressAttack.Enabled and enemy and bedwars.AbilityController:canUseAbility('rebellion_shield', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('rebellion_shield')
						end
	
						if SwapAura.Enabled then
							local wanted = enemy and 'damage' or getHurtAlly(origin) and 'healing' or nil
							if wanted and aura ~= '' and aura ~= wanted and bedwars.AbilityController:canUseAbility('rebellion_aura_swap', {disableBlockedAbilityAlert = true}) then
								bedwars.AbilityController:useAbility('rebellion_aura_swap')
							end
						end
					end
					task.wait(0.1)
				until not AutoSilas.Enabled
			end
		end,
		Tooltip = 'Automatically swaps your aura and rallies your team'
	})
	
	Range = AutoSilas:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	SwapAura = AutoSilas:CreateToggle({
		Name = 'Swap aura',
		Default = true,
		Tooltip = 'Uses the damage aura near enemies and the healing aura near hurt allies'
	})
	PressAttack = AutoSilas:CreateToggle({
		Name = 'Press the attack',
		Default = true,
		Tooltip = 'Uses the shield ability when an enemy gets close'
	})
end)

run(function()
	local AutoSmoke
	local Range
	local Health
	local Delay
	local nextBomb = 0
	
	AutoSmoke = vape.Categories.Kits:CreateModule({
		Name = 'AutoSmoke',
		Function = function(callback)
			if callback then
				nextBomb = 0
	
				repeat
					local bomb = entitylib.isAlive and store.equippedKit == 'smoke' and tick() >= nextBomb and getItem('smoke_bomb') or nil
					if bomb and entitylib.character.Health <= (entitylib.character.MaxHealth * (Health.Value / 100)) then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})
	
						if target then
							nextBomb = tick() + Delay.Value
							bedwars.Handler:Get('ConsumeItem'):Fire('CallServer', {item = bomb.tool})
						end
					end
					task.wait(0.1)
				until not AutoSmoke.Enabled
			end
		end,
		Tooltip = 'Automatically pops a smoke bomb when you are low with enemies nearby'
	})
	
	Range = AutoSmoke:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Health = AutoSmoke:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Pops the bomb at or below this much health'
	})
	Delay = AutoSmoke:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 15,
		Default = 5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoSophia
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0
	local nextSwap = 0
	
	local staffs = {'frost_staff_3', 'frost_staff_2', 'frost_staff_1'}
	
	local function shootStaff()
		local item, itemType
		for _, v in staffs do
			item = getItem(v)
			if item then
				itemType = v
				break
			end
		end
		local source = item and bedwars.ItemMeta[itemType].projectileSource or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end
	
		local ready = bedwars.FrostyGunController.projectileMode == bedwars.FrostyGunMode.PROJECTILE
		local swapping = not ready and tick() >= nextSwap and bedwars.AbilityController:canUseAbility('frosty_gun_swap', {disableBlockedAbilityAlert = true})
		if not ready and not swapping then return end
	
		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if ready then
				if fireProjectile(item, itemType, source.projectileType(itemType), target) then
					nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
					task.wait(SwitchDelay.Value)
				end
			else
				nextSwap = tick() + 1
				bedwars.AbilityController:useAbility('frosty_gun_swap')
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end
	
	AutoSophia = vape.Categories.Kits:CreateModule({
		Name = 'AutoSophia',
		Function = function(callback)
			if callback then
				nextFire, nextSwap = 0, 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'winter_lady' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						shootStaff()
					end
					task.wait(0.1)
				until not AutoSophia.Enabled
			end
		end,
		Tooltip = 'Automatically shoots Sophia\'s frost staff at whoever you\'re meleeing, swapping it out of mist mode when needed'
	})
	
	Targets = AutoSophia:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoSophia:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoSophia:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoSophia:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoStar
	local Streamer
	local Range
	local Animation
	local Delay
	
	local cooldowns = {}
	
	AutoStar = vape.Categories.Kits:CreateModule({
		Name = 'AutoStarCollector',
		Function = function(callback)
			if callback then
				AutoStar:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'stars_ProximityPrompt' then
						task.wait(0.1)
						prompt:InputHoldBegin()
					end
				end))
	
				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('stars') do
							if tick() > (cooldowns[v] or 0) and v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
	
								if (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									end
	
									bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoStar.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically collects stars'
	})
	
	Streamer = AutoStar:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Delay then
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Useful for when ur screensharing'
	})
	Animation = AutoStar:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoStar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	Delay = AutoStar:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoTaliyah
	local Emerald
	local Diamond
	local Iron
	local Amount
	
	local function getShopId()
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
					return v.Id
				end
			end
		end
		return
	end
	
	AutoTaliyah = vape.Categories.Kits:CreateModule({
		Name = 'AutoTaliyah',
		Function = function(callback)
			if callback then
				local item = bedwars.Shop.getShopItem('chicken_shop_item', lplr)
	
				repeat
					local id = getShopId()
					if id then
						local chickenData = bedwars.TaliyahUtil:getPrice()
						if (chickenData.currency == 'emerald' and Emerald.Enabled or chickenData.currency == 'iron' and Iron.Enabled or chickenData.currency == 'diamond' and Diamond.Enabled) and chickenData.price >= Amount.Value then
							bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
								shopItem = item,
								shopId = id
							}):andThen(function(suc)
								if suc then
									bedwars.AudioManager:playAudio(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
									bedwars.Store:dispatch({
										type = 'BedwarsAddItemPurchased',
										itemType = item.itemType
									})
									bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
								end
							end)
						end
					end
					task.wait(0.1)
				until not AutoTaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically buy chickens when it sells for emerald'
	})
	
	Iron = AutoTaliyah:CreateToggle({
		Name = 'Iron',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is iron'
	})
	Emerald = AutoTaliyah:CreateToggle({
		Name = 'Emerald',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is emerald'
	})
	Diamond = AutoTaliyah:CreateToggle({
		Name = 'Diamond',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is diamond'
	})
	Amount = AutoTaliyah:CreateSlider({
		Name = 'Amount',
		Min = 1,
		Max = 1000,
		Default = 2,
		Tooltip = 'Only sells if the currency is selling for the selected amount'
	})
end)

run(function()
	local AutoTriton
	local Legit
	local Back
	local BackDelay
	local Limit
	local FallSpeed
	local Search
	local nextFire = 0
	
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	
	local function getNearGround(origin)
		for i = 1, Search.Value do
			for _, v in {Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.zAxis} do
				local ray = workspace:Raycast((origin + Vector3.new(0, 3, 0)) + (v * i), Vector3.new(0, -80, 0), rayCheck)
				if ray then
					return ray.Position
				end
			end
		end
		return nil
	end
	
	local function fireHarpoon(item, spot)
		local meta = bedwars.ProjectileMeta.harpoon_projectile
		local source = bedwars.ItemMeta[item.itemType].projectileSource
		local origin = entitylib.character.RootPart.Position
		local speed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
		local shootPosition = (CFrame.new(origin, spot) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
		local calc = prediction.SolveTrajectory(shootPosition, speed, gravity, spot, Vector3.zero, workspace.Gravity, 0, nil, nil, false, spot)
		if not calc then return false end
	
		local hotbar, previous = getHotbar(item.tool), store.hand.tool
		switchItem(item.tool)
		if Legit.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end
	
		nextFire = tick() + (source and source.fireDelaySec or 8)
		bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
			item.tool,
			item.itemType,
			source and source.projectileType(item.itemType) or 'harpoon_projectile',
			shootPosition,
			origin,
			CFrame.lookAt(shootPosition, calc).LookVector * speed,
			httpService:GenerateGUID(true),
			{
				drawDurationSeconds = 1,
				shotId = httpService:GenerateGUID(false)
			},
			workspace:GetServerTimeNow() - 0.045
		):andThen(function(res)
			if res then
				res.Parent = replicatedStorage
			end
		end)
	
		if Back.Enabled and previous then
			task.wait(BackDelay:GetRandomValue())
			switchItem(previous)
			if Legit.Enabled and getHotbar(previous) then
				hotbarSwitch(getHotbar(previous))
			end
		end
		return true
	end
	
	AutoTriton = vape.Categories.Kits:CreateModule({
		Name = 'AutoTriton',
		Function = function(callback)
			if callback then
				nextFire = 0
				local lastground
	
				repeat
					if entitylib.isAlive and tick() >= nextFire and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'harpoon') then
						local root = entitylib.character.RootPart
						local harpoon = getItem('harpoon')
						rayCheck.FilterDescendantsInstances = {store.map}
						rayCheck.CollisionGroup = root.CollisionGroup
	
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lastground = root.Position
						end
	
						if harpoon and root.AssemblyLinearVelocity.Y < -FallSpeed.Value and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							local spot = getNearGround(root.Position + Vector3.new(0, 40, 0)) or lastground and getNearGround(lastground + Vector3.new(0, 5, 0))
							if spot then
								fireHarpoon(harpoon, spot)
							end
						end
					end
					task.wait(0.1)
				until not AutoTriton.Enabled
			end
		end,
		Tooltip = 'Automatically throws the trident onto nearby ground when you are falling into the void'
	})
	
	FallSpeed = AutoTriton:CreateSlider({
		Name = 'Fall speed',
		Min = 10,
		Max = 200,
		Default = 60,
		Suffix = 'studs a second',
		Tooltip = 'How fast you have to be falling before it throws'
	})
	Search = AutoTriton:CreateSlider({
		Name = 'Search range',
		Min = 4,
		Max = 60,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far out it looks for ground to land on'
	})
	Legit = AutoTriton:CreateToggle({
		Name = 'Legit Switch',
		Default = true,
		Tooltip = 'Visualizes the switching clientside'
	})
	Back = AutoTriton:CreateToggle({
		Name = 'Switch back',
		Function = function(callback)
			if BackDelay then
				BackDelay.Object.Visible = callback
			end
		end,
		Default = true,
		Tooltip = 'Switches back to the last slot after throwing'
	})
	BackDelay = AutoTriton:CreateTwoSlider({
		Name = 'Switch Back Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Limit = AutoTriton:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only throws when you are already holding the trident'
	})
end)

run(function()
	local AutoTrixie
	local Targets
	local Warp
	local WarpRange
	local Rewind
	local Health
	local nextAbility = 0
	
	AutoTrixie = vape.Categories.Kits:CreateModule({
		Name = 'AutoTrixie',
		Function = function(callback)
			if callback then
				nextAbility = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_walker' and tick() >= nextAbility then
						local humanoid = entitylib.character.Humanoid
	
						if Rewind.Enabled and humanoid.Health <= (humanoid.MaxHealth * (Health.Value / 100)) and bedwars.AbilityController:canUseAbility('void_walker_rewind', {disableBlockedAbilityAlert = true}) then
							nextAbility = tick() + 1
							bedwars.AbilityController:useAbility('void_walker_rewind')
						elseif Warp.Enabled and bedwars.AbilityController:canUseAbility('void_walker_warp', {disableBlockedAbilityAlert = true}) then
							local target = entitylib.EntityPosition({
								Range = WarpRange.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled,
								Sort = sortmethods.Distance
							})
	
							if target then
								local root = entitylib.character.RootPart
								root.CFrame = CFrame.lookAlong(root.Position, (target.RootPart.Position - root.Position) * Vector3.new(1, 0, 1))
								nextAbility = tick() + 1
								bedwars.AbilityController:useAbility('void_walker_warp')
							end
						end
					end
					task.wait(0.1)
				until not AutoTrixie.Enabled
			end
		end,
		Tooltip = 'Warps you onto whoever you are chasing and rifts you back out when it goes wrong'
	})
	
	Targets = AutoTrixie:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Warp = AutoTrixie:CreateToggle({
		Name = 'Warp to target',
		Default = true,
		Function = function(callback)
			if WarpRange then
				WarpRange.Object.Visible = callback
			end
		end,
		Tooltip = 'Turns you at the closest enemy before warping so the portal lands on them'
	})
	WarpRange = AutoTrixie:CreateSlider({
		Name = 'Warp range',
		Min = 5,
		Max = 80,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Rewind = AutoTrixie:CreateToggle({
		Name = 'Rewind on low health',
		Default = true,
		Function = function(callback)
			if Health then
				Health.Object.Visible = callback
			end
		end
	})
	Health = AutoTrixie:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 40,
		Suffix = '%'
	})
	
end)

run(function()
	local AutoUma
	local Range
	local Limit
	local Animation
	local AutoSummon
	local HealSpirit
	local AttackSpirit
	local TargetItemDrops
	local Diamond
	local Emerald
	
	local function getAttackData()
		if Limit.Enabled then
			local tool = (store.hand.tool and store.hand.tool.Name == 'spirit_staff') and store.hand.tool or nil
			return tool, tool and getHotbar(tool) or nil
		end
		for i, v in store.inventory.inventory.items do
			if v.itemType == 'spirit_staff' then
				switchItem(v, 0)
				return v, i
			end
		end
		return
	end
	
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	
	local function fireSpirit(staff, spiritType, drop)
		local meta = bedwars.ProjectileMeta[spiritType]
		if not meta then return false end
	
		local localPosition = entitylib.character.RootPart.Position
		local shootpos = localPosition + Vector3.new(0, 2, 0)
		rayCheck.FilterDescendantsInstances = store.map and {store.map} or {}
	
		local calc = prediction.SolveTrajectory(shootpos, meta.launchVelocity, meta.gravitationalAcceleration or 196.2, drop.Position, Vector3.zero, workspace.Gravity, 0, 0, rayCheck)
		if not calc then return false end
	
		bedwars.Handler:Get('ProjectileFire'):Fire('CallServerAsync',
			staff,
			nil,
			spiritType,
			shootpos,
			localPosition,
			CFrame.lookAt(shootpos, calc).LookVector * meta.launchVelocity,
			httpService:GenerateGUID(true),
			{
				drawDurationSeconds = 1,
				shotId = httpService:GenerateGUID(false)
			},
			workspace:GetServerTimeNow() - 0.045
		)
	
		return true
	end
	
	local function getDrops(localPosition, ItemDrops)
		local drop, lastmag = nil, Range.Value + 1
		for i, v in ItemDrops do
			if v.Name == 'emerald' and Emerald.Enabled or v.Name == 'diamond' and Diamond.Enabled then
				local magnitude = (localPosition - v.Position).Magnitude
				if magnitude <= lastmag and not entitylib.Wallcheck(localPosition, v.Position, {gameCamera, lplr.Character, v}) then
					drop, lastmag = v, magnitude
				end
			end
		end
		return drop
	end
	
	AutoUma = vape.Categories.Kits:CreateModule({
		Name = 'AutoUma',
		Function = function(call)
			if call then
				local items = collection('ItemDrop', AutoUma)
				repeat
					local staff = getAttackData()
					if staff then
						if TargetItemDrops.Enabled then
							local attackSpirits = (lplr:GetAttribute('ReadySummonedAttackSpirits') or 0)
							local healSpirits = (lplr:GetAttribute('ReadySummonedHealSpirits') or 0)
	
							if AutoSummon.Enabled then
								if AttackSpirit.Enabled and attackSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_attack_spirit')
								end
	
								if HealSpirit.Enabled and healSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_heal_spirit')
								end
							end
	
							if (healSpirits + attackSpirits) > 0 then
								local localPosition = entitylib.character.RootPart.Position
								local drop = getDrops(localPosition, items)
								if drop and fireSpirit(staff, attackSpirits > 0 and 'attack_spirit' or 'heal_spirit', drop) then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.WIZARD_BALL_CAST)
										bedwars.AudioManager:playAudio(bedwars.SoundList.SPIRIT_SUMMONER_CHANGE_AFFINITY, {})
									end
	
									task.wait(1.5)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoUma.Enabled
			end
		end,
		Tooltip = 'Automatically throw spirits at item drops and opponents.'
	})
	
	Range = AutoUma:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 50,
		Decimal = 5,
		Suffix = function(val)
			return val >= 2 and 'studs' or 'stud'
		end
	})
	Animation = AutoUma:CreateToggle({
		Name = 'Animation',
		Default = true
	})
	Limit = AutoUma:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	AutoSummon = AutoUma:CreateToggle({
		Name = 'Auto Summon',
		Function = function(call)
			if AttackSpirit then
				AttackSpirit.Object.Visible = call
				HealSpirit.Object.Visible = call
			end
		end,
		Tooltip = 'Automattically summons spirit for you'
	})
	HealSpirit = AutoUma:CreateToggle({
		Name = 'Use heal spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	AttackSpirit = AutoUma:CreateToggle({
		Name = 'Use attack spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	TargetItemDrops = AutoUma:CreateToggle({
		Name = 'Target item drops',
		Function = function(call)
			if Emerald then
				Emerald.Object.Visible = call
				Diamond.Object.Visible = call
			end
		end,
		Default = true
	})
	Emerald = AutoUma:CreateToggle({
		Name = 'Emerald',
		Darker = true,
		Default = true
	})
	Diamond = AutoUma:CreateToggle({
		Name = 'Diamond',
		Darker = true,
		Default = true
	})
end)

run(function()
	local old, overcharge
	
	vape.Categories.Kits:CreateModule({
		Name = 'AutoVanessa',
		Function = function(callback)
			if callback then
				old = bedwars.TripleShotProjectileController.getChargeTime
				overcharge = bedwars.TripleShotProjectileController.overchargeStartTime
				bedwars.TripleShotProjectileController.getChargeTime = function()
					return 0
				end
				bedwars.TripleShotProjectileController.overchargeStartTime = tick()
			else
				bedwars.TripleShotProjectileController.getChargeTime = old
				bedwars.TripleShotProjectileController.overchargeStartTime = overcharge
			end
		end,
		Tooltip = 'Fully charges your bow instantly and enables triple shot as Vanessa'
	})
end)

run(function()
	local AutoVoidKnight
	local Iron
	local Emeralds
	local Keep
	local Ascend
	local Range
	
	local function feed(itemType, ability)
		local item = getItem(itemType)
		if item and item.amount > Keep.Value and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			bedwars.AbilityController:useAbility(ability)
		end
	end
	
	AutoVoidKnight = vape.Categories.Kits:CreateModule({
		Name = 'AutoVoidKnight',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_knight' then
						if Iron.Enabled then
							feed('iron', 'void_knight_consume_iron')
						end
	
						if Emeralds.Enabled then
							feed('emerald', 'void_knight_consume_emerald')
						end
	
						if Ascend.Enabled and bedwars.AbilityController:canUseAbility('void_knight_ascend', {disableBlockedAbilityAlert = true}) then
							local near = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							})
							if near then
								bedwars.AbilityController:useAbility('void_knight_ascend')
							end
						end
					end
					task.wait(0.2)
				until not AutoVoidKnight.Enabled
			end
		end,
		Tooltip = 'Automatically feeds your resources into the void and ascends in fights'
	})
	
	Keep = AutoVoidKnight:CreateSlider({
		Name = 'Keep',
		Min = 0,
		Max = 64,
		Default = 0,
		Tooltip = 'Resources left untouched in your inventory'
	})
	Range = AutoVoidKnight:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Iron = AutoVoidKnight:CreateToggle({
		Name = 'Iron',
		Default = true
	})
	Emeralds = AutoVoidKnight:CreateToggle({
		Name = 'Emeralds',
		Default = true
	})
	Ascend = AutoVoidKnight:CreateToggle({
		Name = 'Ascend',
		Default = true,
		Tooltip = 'Uses void ascension when an enemy is close'
	})
end)

run(function()
	local AutoWarden
	local Range
	
	local collected = setmetatable({}, {__mode = 'k'})
	
	AutoWarden = vape.Categories.Kits:CreateModule({
		Name = 'AutoWarden',
		Function = function(callback)
			if callback then
				table.clear(collected)
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'jailor' then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('jailor_soul') do
							if not collected[v] and v.PrimaryPart and (v.PrimaryPart.Position - origin).Magnitude <= Range.Value then
								collected[v] = true
								bedwars.JailorController:collectEntity(lplr, v, v.Name)
							end
						end
					end
					task.wait(0.1)
				until not AutoWarden.Enabled
			end
		end,
		Tooltip = 'Automatically imprisons the souls dropped by enemies you kill'
	})
	
	Range = AutoWarden:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoWarrior
	local Targets
	local Range
	local Amount
	
	AutoWarrior = vape.Categories.Kits:CreateModule({
		Name = 'AutoWarrior',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'warrior' and bedwars.AbilityController:canUseAbility('warrior_strike', {disableBlockedAbilityAlert = true}) then
						local found = #entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if found >= Amount.Value then
							bedwars.AbilityController:useAbility('warrior_strike')
						end
					end
					task.wait(0.1)
				until not AutoWarrior.Enabled
			end
		end,
		Tooltip = 'Automatically uses Warriors Strike once enough enemies are next to you'
	})
	
	Targets = AutoWarrior:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = AutoWarrior:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 14,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Amount = AutoWarrior:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before striking'
	})
	
end)

run(function()
	local AutoWhim
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0
	
	local function castSpell()
		local item = getItem('mage_spellbook')
		local util = bedwars.MageKitUtil
		local element = bedwars.BalanceFile.MAGE_ELEMENT_CYCLE[(lplr:GetAttribute('MageElementIndex') or 0) + 1]
		if not element or table.find(util.getUnlockedMageElements(lplr), element) == nil then
			element = 'BASE'
		end
	
		local meta = util.MageElementMeta[element]
		local source = item and meta and meta.projectileSource or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end
	
		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'mage_spellbook', source.projectileType('mage_spellbook'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end
	
	AutoWhim = vape.Categories.Kits:CreateModule({
		Name = 'AutoWhim',
		Function = function(callback)
			if callback then
				nextFire = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'mage' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						castSpell()
					end
					task.wait(0.1)
				until not AutoWhim.Enabled
			end
		end,
		Tooltip = 'Automatically casts Whim\'s magic book at whoever you\'re meleeing'
	})
	
	Targets = AutoWhim:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoWhim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoWhim:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoWhim:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoWhisper
	local Heal
	local Threshold
	local Fly
	local Owl
	local Target
	
	local teammates = {'None'}
	local old
	
	local function getOwl()
		for _, v in collectionService:GetTagged('Owl') do
			if v:GetAttribute('Owner') == lplr.UserId then
				return v
			end
		end
		return nil
	end
	
	local function addConnection(plr, connected)
		if not connected then
			vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
				addConnection(plr, true)
			end))
		end
	
		if plr ~= lplr and plr:GetAttribute('Team') == lplr:GetAttribute('Team') and not table.find(teammates, plr.Name) then
			table.insert(teammates, plr.Name)
			Target:Change(teammates)
		end
	end
	
	AutoWhisper = vape.Categories.Kits:CreateModule({
		Name = 'AutoWhisper',
		Function = function(callback)
			if callback then
				local lowestpoint = math.huge
	
				old = bedwars.OwlKitController.onAbilityUsed
				bedwars.OwlKitController.onAbilityUsed = function(self, character, data, ...)
					if Owl.Enabled and data and data.ability == 'SUMMON_OWL' and character == lplr.Character then
						local plr = playersService:FindFirstChild(Target.Value)
						if plr and plr ~= lplr then
							bedwars.Handler:Get('SummonOwl'):Fire('CallServer', plr)
							return
						end
					end
					return old(self, character, data, ...)
				end
	
				repeat
					task.wait()
				until store.matchState ~= 0 or not AutoWhisper.Enabled
				if not AutoWhisper.Enabled then
					return
				end
	
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if Owl.Enabled and not getOwl() and playersService:FindFirstChild(Target.Value) and bedwars.AbilityController:canUseAbility('SUMMON_OWL', {disableBlockedAbilityAlert = true}) then
						bedwars.AbilityController:useAbility('SUMMON_OWL')
					end
	
					local liftReady = Fly.Enabled and workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlLiftReadyTime') or 0) > 0
					local healReady = Heal.Enabled and workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlHealReadyTime') or 0) > 0
					if liftReady or healReady then
						for _, v in collectionService:GetTagged('Owl') do
							if v:GetAttribute('Owner') == lplr.UserId then
								local plr = playersService:GetPlayerByUserId(v:GetAttribute('Target'))
								local char = plr and plr.Character
								local root = char and char:FindFirstChild('HumanoidRootPart')
								if root then
									if liftReady and root.AssemblyLinearVelocity.Y < -10 and root.Position.Y < lowestpoint then
										bedwars.AbilityController:useAbility('OWL_LIFT')
									end
	
									local health = char:GetAttribute('Health')
									local maxHealth = char:GetAttribute('MaxHealth')
									if healReady and (Threshold.Value >= 100 or health and maxHealth and maxHealth > 0 and health / maxHealth <= Threshold.Value / 100) then
										bedwars.AbilityController:useAbility('OWL_HEAL')
									end
								end
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoWhisper.Enabled
			elseif old then
				bedwars.OwlKitController.onAbilityUsed = old
				old = nil
			end
		end,
		Tooltip = 'Automatically uses whisper abilities'
	})
	
	Heal = AutoWhisper:CreateToggle({
		Name = 'Heal',
		Function = function(call)
			if Threshold then
				Threshold.Object.Visible = call
			end
		end,
		Default = true
	})
	Threshold = AutoWhisper:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 99,
		Darker = true,
		Suffix = '%'
	})
	Fly = AutoWhisper:CreateToggle({
		Name = 'Fly',
		Default = true
	})
	Owl = AutoWhisper:CreateToggle({
		Name = 'Auto owl',
		Function = function(call)
			if Target then
				Target.Object.Visible = call
			end
		end,
		Tooltip = 'Sends the owl to the teammate you pick as soon as the ability is up'
	})
	Target = AutoWhisper:CreateDropdown({
		Name = 'Teammate',
		List = teammates,
		Darker = true,
		Visible = false,
		Tooltip = 'Who the owl gets summoned onto'
	})
	
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)

run(function()
	local AutoXurot
	local Range
	local Delay
	local dragonForm = false
	local nextBreath = 0
	
	local Breath = bedwars.Handler:Get('DragonBreath')
	
	local function isLocal(data)
		if type(data) ~= 'table' then return true end
		return data.player == nil or data.player == lplr
	end
	
	AutoXurot = vape.Categories.Kits:CreateModule({
		Name = 'AutoXurot',
		Function = function(callback)
			if callback then
				dragonForm, nextBreath = false, 0
	
				local action = bedwars.Handler:Get('VoidDragonAction')
				if action.Remote then
					AutoXurot:Clean(action.Remote:Connect(function(data)
						if isLocal(data) then
							if data.action == 'transform' then
								dragonForm = true
							elseif data.action == 'dragon_deactive' then
								dragonForm = false
							end
						end
					end))
				end
	
				local deactive = bedwars.Handler:Get('VoidDragonDeactive')
				if deactive.Remote then
					AutoXurot:Clean(deactive.Remote:Connect(function(data)
						if isLocal(data) then
							dragonForm = false
						end
					end))
				end
	
				AutoXurot:Clean(lplr.CharacterAdded:Connect(function()
					dragonForm = false
				end))
	
				repeat
					if dragonForm and entitylib.isAlive and store.equippedKit == 'void_dragon' and tick() >= nextBreath then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
	
						if target then
							nextBreath = tick() + Delay.Value
							Breath:Fire('SendToServer', {player = lplr, targetPoint = target.RootPart.Position})
						end
					end
					task.wait(0.05)
				until not AutoXurot.Enabled
			end
		end,
		Tooltip = 'Automatically breathes on enemies while you are in dragon form'
	})
	
	Range = AutoXurot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 200,
		Default = 120,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoXurot:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoYeti
	local Range
	local Targets
	
	AutoYeti = vape.Categories.Kits:CreateModule({
		Name = 'AutoYeti',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'yeti' and bedwars.AbilityController:canUseAbility('yeti_glacial_roar', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end
	
						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('yeti_glacial_roar')
						end
					end
					task.wait(0.1)
				until not AutoYeti.Enabled
			end
		end,
		Tooltip = 'Automatically roars once enough enemies are around you'
	})
	
	Range = AutoYeti:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoYeti:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before roaring'
	})
end)

run(function()
	local AutoZeno
	local Targets
	local TargetMode
	local Limit
	local AFKCheck
	local AutoShockWave
	local ShockwaveRange
	local UseStrike
	local UseStorm
	local Range
	local Delay
	
	local function getAttackData()
		if Limit.Enabled then
			local tool = store.hand.tool
			local itemType = tool and tool.Name
			if itemType and bedwars.WizardUtil:isWizardStaff(itemType) then
				return tool, itemType
			end
			return nil
		end
	
		for _, v in store.inventory.inventory.items do
			if bedwars.WizardUtil:isWizardStaff(v.itemType) and v.tool then
				switchItem(v.tool, 0)
				return v.tool, v.itemType
			end
		end
	
		return nil
	end
	
	AutoZeno = vape.Categories.Kits:CreateModule({
		Name = 'AutoZeno',
		Function = function(callback)
			if callback then
				local attempts = {}
				repeat
					if entitylib.isAlive and not (AFKCheck.Enabled and isAfk()) then
						local staff, itemType = getAttackData()
						if staff and itemType then
							local localPosition = entitylib.character.RootPart.Position
							local castRange = math.min(Range.Value, bedwars.WizardUtil:getCastRange(itemType))
							local shockwave = AutoShockWave.Enabled and bedwars.WizardUtil:hasAbility(itemType, 'SHOCKWAVE')
							local ent = entitylib.EntityPosition({
								Origin = localPosition,
								Range = math.max(castRange, shockwave and ShockwaveRange.Value or 0),
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Priority = Targets.Priority.Value,
								Sort = sortmethods[TargetMode.Value]
							})
	
							if ent then
								local distance = (localPosition - ent.RootPart.Position).Magnitude
								local target = ent.RootPart.Position + ((ent.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
								local abilities = {
									{'LIGHTNING_STORM', UseStorm.Enabled and distance <= castRange},
									{'SHOCKWAVE', shockwave and distance <= ShockwaveRange.Value},
									{'LIGHTNING_STRIKE', UseStrike.Enabled and distance <= castRange}
								}
	
								for _, v in abilities do
									if not v[2] or (attempts[v[1]] or 0) > tick() then continue end
									if not bedwars.WizardUtil:hasAbility(itemType, v[1]) then continue end
	
									local controller = bedwars.WizardStaffController
									if not controller then continue end
	
									local suc, allowed = pcall(controller.canCastAbility, controller, v[1])
									if not suc or not allowed then continue end
									suc, allowed = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, v[1], {disableBlockedAbilityAlert = true})
									if not suc or not allowed then continue end
	
									attempts[v[1]] = tick() + math.max(Delay.Value, 0.25)
									if pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, v[1], newproxy(true), {target = v[1] == 'SHOCKWAVE' and Vector3.zero or target}) then
										task.wait(Delay.Value)
										break
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoZeno.Enabled
			end
		end,
		Tooltip = 'Automatically uses zeno\'s staff.'
	})
	
	Targets = AutoZeno:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	TargetMode = AutoZeno:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Limit = AutoZeno:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	AFKCheck = AutoZeno:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops casting once you have not touched your mouse or keyboard for 30 seconds'
	})
	UseStrike = AutoZeno:CreateToggle({
		Name = 'Use Lightning Strike',
		Default = true
	})
	UseStorm = AutoZeno:CreateToggle({Name = 'Use Lightning Storm'})
	AutoShockWave = AutoZeno:CreateToggle({
		Name = 'Auto Shockwave',
		Function = function(callback)
			if ShockwaveRange then
				ShockwaveRange.Object.Visible = callback
			end
		end,
		Tooltip = 'Automatically uses the shockwave ability when a target is near'
	})
	ShockwaveRange = AutoZeno:CreateSlider({
		Name = 'Shockwave Range',
		Min = 1,
		Max = 12,
		Decimal = 5,
		Default = 12,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	Range = AutoZeno:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Decimal = 5,
		Default = 35,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	Delay = AutoZeno:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 10,
		Decimal = 5,
		Default = 0.5,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoZola
	local Mode
	local Range
	local links = {}
	local nextLink = 0
	
	local function isLinked(char)
		local expiry = links[char]
		if expiry and expiry > tick() then
			return true
		end
		links[char] = nil
		return false
	end
	
	local function attemptLink(char)
		if not char or tick() < nextLink or isLinked(char) then return end
		local count = 0
		for i in links do
			if isLinked(i) then
				count += 1
			end
		end
		if count >= bedwars.SoulBrokerConstants.MAX_SOUL_LINKS then return end
	
		links[char] = tick() + 1
		nextLink = tick() + 1
		bedwars.Handler:Get('AttemptSoulLink'):Fire('CallServerAsync', char)
	end
	
	AutoZola = vape.Categories.Kits:CreateModule({
		Name = 'AutoZola',
		Function = function(callback)
			if callback then
				AutoZola:Clean(bedwars.Handler:Get('SoulLinkFormed').Remote:Connect(function(linkTable)
					if linkTable.broker == lplr and not linkTable.guard then
						links[linkTable.target] = tick() + bedwars.SoulBrokerConstants.SOUL_LINK_DURATION
					end
				end))
	
				AutoZola:Clean(bedwars.Handler:Get('SoulLinkRemoved').Remote:Connect(function(linkTable)
					if linkTable.broker == lplr and not linkTable.guard then
						links[linkTable.target] = nil
					end
				end))
	
				AutoZola:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if Mode.Value ~= 'On Hit' or damageTable.fromEntity ~= lplr.Character then return end
					if not entitylib.isAlive or store.equippedKit ~= 'soul_broker' then return end
	
					local target = entitylib.getEntity(damageTable.entityInstance)
					if target and target.Player and target.Targetable and (entitylib.character.RootPart.Position - target.RootPart.Position).Magnitude <= Range.Value then
						attemptLink(target.Character)
					end
				end))
	
				repeat
					if Mode.Value == 'On See' and tick() >= nextLink and entitylib.isAlive and store.equippedKit == 'soul_broker' then
						for _, v in entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						}) do
							if not isLinked(v.Character) then
								attemptLink(v.Character)
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoZola.Enabled
			end
		end,
		Tooltip = 'Automatically soul links enemies'
	})
	
	Mode = AutoZola:CreateDropdown({
		Name = 'Mode',
		List = {'On See', 'On Hit'},
		Tooltip = 'On See - Links enemies as soon as you can see them\nOn Hit - Links enemies whenever you hit them',
		Default = 'On See'
	})
	Range = AutoZola:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local CryptAura
	local Range
	local Delay
	local nextClaim = 0
	
	local claimed = setmetatable({}, {__mode = 'k'})
	
	local Activate = bedwars.Handler:Get('ActivateGravestone')
	
	CryptAura = vape.Categories.Kits:CreateModule({
		Name = 'CryptAura',
		Function = function(callback)
			if callback then
				nextClaim = 0
				table.clear(claimed)
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'necromancer' and tick() >= nextClaim then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('Gravestone') do
							if not claimed[v] and v:GetAttribute('GravestoneSecret') and (v:GetPivot().Position - origin).Magnitude <= Range.Value then
								claimed[v] = true
								nextClaim = tick() + Delay.Value
								Activate:Fire('CallServer', {
									secret = v:GetAttribute('GravestoneSecret'),
									position = v:GetAttribute('GravestonePosition'),
									skeletonData = {
										associatedPlayerUserId = v:GetAttribute('GravestonePlayerUserId'),
										armorType = v:GetAttribute('ArmorType'),
										weaponType = v:GetAttribute('SwordType'),
										bowType = v:GetAttribute('BowType')
									}
								})
								break
							end
						end
					end
					task.wait(0.1)
				until not CryptAura.Enabled
			end
		end,
		Tooltip = 'Automatically claims the gravestones enemies drop into your undead army'
	})
	
	Range = CryptAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = CryptAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local DaveyAim
	local Mode
	local Position
	local Range
	local PlaceCannon
	local Switch
	local LaunchCannon
	local ShowTarget
	
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	local function placeCannon()
		local item = getItem('cannon')
		if not item then
			notif('DaveyAim', 'No cannon in your inventory.', 5, 'warning')
			return nil
		end
	
		local root = entitylib.character.RootPart
		local feet = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + 1.5, 0))
		local spot, closest = nil, math.huge
	
		for x = -3, 3 do
			for z = -3, 3 do
				for y = 0, 1 do
					local pos = feet + Vector3.new(x * 3, y * 3, z * 3)
					local mag = (root.Position - pos).Magnitude
					if mag > Range.Value or mag >= closest or pos == feet or pos == feet + Vector3.yAxis * 3 then continue end
					if getPlacedBlock(pos) or getPlacedBlock(pos + Vector3.yAxis * 3) or not getPlacedBlock(pos - Vector3.yAxis * 3) then continue end
					spot, closest = pos, mag
				end
			end
		end
	
		local pos = spot
		if not pos then
			notif('DaveyAim', 'Nowhere to put a cannon.', 5, 'warning')
			return nil
		end
	
		if Switch.Enabled then
			switchItem(item.tool)
			local hotbar = getHotbar(item.tool)
			if hotbar then
				hotbarSwitch(hotbar)
			end
		end
	
		bedwars.placeBlock(pos, 'cannon')
	
		local timeout = tick() + 1
		repeat
			task.wait(0.05)
			for _, v in collectionService:GetTagged('cannon') do
				if (v.Position - pos).Magnitude < 1.5 then
					return v
				end
			end
		until tick() > timeout
	
		return nil
	end
	
	local function getApex(delta, velocity, time)
		local rise = ((delta + Vector3.new(0, workspace.Gravity * time * time * 0.5, 0)) / time - velocity).Y
		return rise > 0 and (rise * rise) / (2 * workspace.Gravity) or 0
	end
	
	local function findLaunchSpeed(func, depth)
		local success, constants = pcall(debug.getconstants, func)
		if not success then return end
	
		local speed, matched
		for _, v in constants do
			if v == 'LaunchSelfFromCannon' then
				matched = true
			elseif type(v) == 'number' and v > 0 then
				speed = speed or v
			end
		end
		if matched and speed then return speed end
		if (depth or 0) >= 3 then return end
	
		local found, upvalues = pcall(debug.getupvalues, func)
		if not found then return end
	
		for _, v in upvalues do
			if type(v) == 'function' then
				local result = findLaunchSpeed(v, (depth or 0) + 1)
				if result then return result end
			end
		end
	end
	
	local function solveTime(delta, velocity, speed, fast, slow)
		for _ = 1, 60 do
			local middle = (fast + slow) / 2
			if ((delta + Vector3.new(0, workspace.Gravity * middle * middle * 0.5, 0)) / middle - velocity).Magnitude > speed then
				fast = middle
			else
				slow = middle
			end
		end
	
		return (fast + slow) / 2
	end
	
	local function getLaunchTime(origin, delta, velocity, speed)
		local low, up = 0.0001, 20
	
		for _ = 1, 50 do
			local first, second = low + (up - low) / 3, up - (up - low) / 3
			if ((delta + Vector3.new(0, workspace.Gravity * first * first * 0.5, 0)) / first - velocity).Magnitude < ((delta + Vector3.new(0, workspace.Gravity * second * second * 0.5, 0)) / second - velocity).Magnitude then
				up = second
			else
				low = first
			end
		end
	
		local middle = (low + up) / 2
		if ((delta + Vector3.new(0, workspace.Gravity * middle * middle * 0.5, 0)) / middle - velocity).Magnitude > speed then return end
	
		local candidates = {
			solveTime(delta, velocity, speed, 0.0001, middle),
			solveTime(delta, velocity, speed, 20, middle)
		}
		for i = -24, 24 do
			local time = middle * (1 + i * 0.05)
			if time > 0.05 and ((delta + Vector3.new(0, workspace.Gravity * time * time * 0.5, 0)) / time - velocity).Magnitude <= speed then
				table.insert(candidates, time)
			end
		end
	
		table.sort(candidates, function(a, b)
			return getApex(delta, velocity, a) < getApex(delta, velocity, b)
		end)
	
		for _, v in candidates do
			local arc = (delta + Vector3.new(0, workspace.Gravity * v * v * 0.5, 0)) / v - Vector3.zero
			local previous = origin
			local blocked = false
			for i = 1, 11 do
				local elapsed = v * i / 12
				local point = origin + arc * elapsed - Vector3.new(0, workspace.Gravity * elapsed * elapsed * 0.5, 0)
				if workspace:Spherecast(previous, 2, point - previous, rayCheck) then
					blocked = true
					break
				end
				previous = point
			end
	
			if not blocked then
				return v
			end
		end
	
		return candidates[#candidates]
	end
	
	DaveyAim = vape.Categories.Kits:CreateModule({
		Name = 'DaveyAim',
		Function = function(callback)
			if callback then
				DaveyAim:Toggle()
				if not entitylib.isAlive then return end
	
				local cannons = {}
				local cannonorigin = entitylib.character.RootPart.Position
				for _, v in store.blocks do
					if v.Name == 'cannon' and (cannonorigin - v.Position).Magnitude <= Range.Value then
						table.insert(cannons, v)
					end
				end
				if #cannons > 1 then
					table.sort(cannons, function(a, b)
						return (cannonorigin - a.Position).Magnitude < (cannonorigin - b.Position).Magnitude
					end)
				end
	
				local cannon = cannons[1] or (PlaceCannon.Enabled and placeCannon())
				if not cannon then
					if not PlaceCannon.Enabled then
						notif('DaveyAim', 'No cannon in range.', 5, 'warning')
					end
					return
				end
	
				local mouseRay = cloneref(lplr:GetMouse()).UnitRay
				local origin = Position.Value == 'Camera' and gameCamera.CFrame.Position or mouseRay.Origin
				local direction = Position.Value == 'Camera' and gameCamera.CFrame.LookVector or mouseRay.Direction
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, cannon}
				local ray = workspace:Raycast(origin, direction * 10000, rayCheck)
				if not ray then
					notif('DaveyAim', 'No position found.', 5, 'warning')
					return
				end
	
				local localPosition = entitylib.character.RootPart.Position
				local target = ray.Position + Vector3.new(0, entitylib.character.HipHeight, 0)
				local velocity = entitylib.character.RootPart.AssemblyLinearVelocity
				local cannonSpeed = (findLaunchSpeed(bedwars.CannonHandController.launchSelf) or 200)
				local maxRange = (cannonSpeed * cannonSpeed) / workspace.Gravity
				if (target - localPosition).Magnitude > maxRange then
					notif('DaveyAim', `Too far away ({math.floor((target - localPosition).Magnitude)} studs away, {math.floor(maxRange)} max).`, 5, 'warning')
					return
				end
	
				local time = getLaunchTime(localPosition, target - localPosition, velocity, cannonSpeed)
				if not time then
					notif('DaveyAim', `Out of cannon range ({math.floor((target - localPosition).Magnitude)} studs away, {math.floor(maxRange)} max).`, 5, 'warning')
					return
				end
	
				local launchDirection = (((target - localPosition) + Vector3.new(0, workspace.Gravity * time * time * 0.5, 0)) / time - velocity).Unit
				local visual
				if ShowTarget.Enabled then
					local blockPosition = roundPos(ray.Position - ray.Normal * 1.5)
					visual = Instance.new('Part')
					visual.Size = Vector3.new(3, 3, 3)
					visual.CFrame = CFrame.new(blockPosition)
					visual.Anchored = true
					visual.CanCollide = false
					visual.CanQuery = false
					visual.CanTouch = false
					visual.CastShadow = false
					visual.Transparency = 1
					local selection = Instance.new('SelectionBox')
					selection.Adornee = visual
					selection.LineThickness = 0.04
					selection.Color3 = Color3.new(1, 1, 1)
					selection.SurfaceColor3 = Color3.new(1, 1, 1)
					selection.SurfaceTransparency = 0.75
					selection.Parent = visual
					local tagSize = getfontbounds('Landing (000 studs)', 14, uipallet.Font)
					local billboard = Instance.new('BillboardGui')
					billboard.Name = 'Tag'
					billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
					billboard.StudsOffsetWorldSpace = (target - blockPosition) + Vector3.new(0, 2, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = visual
					local tag = Instance.new('TextLabel')
					tag.Size = billboard.Size
					tag.BackgroundColor3 = Color3.new()
					tag.BackgroundTransparency = 0.5
					tag.BorderSizePixel = 0
					tag.RichText = true
					tag.FontFace = uipallet.Font
					tag.TextSize = 14
					tag.TextColor3 = Color3.new(1, 1, 1)
					tag.Parent = billboard
					bedwars.QueryUtil:setQueryIgnored(visual, true)
					visual.Parent = gameCamera
				end
				if visual then
					visual.Tag.TextLabel.Text = `Landing ({math.floor((target - localPosition).Magnitude)} studs)`
				end
	
				if Mode.Value == 'Legit' then
					local direction = launchDirection
					local startLook = gameCamera.CFrame.LookVector
					local angle = math.deg(math.acos(math.clamp(startLook:Dot(direction), -1, 1)))
					local duration = math.clamp(angle / 300, 0.15, 0.8)
					local elapsed, alpha = 0, 0
	
					repeat
						elapsed += runService.PostSimulation:Wait()
						alpha = math.clamp(elapsed / duration, 0, 1)
						local eased = alpha < 0.5 and (2 * alpha * alpha) or (1 - ((-2 * alpha + 2) ^ 2) / 2)
						local look = startLook:Lerp(direction, eased)
						if look.Magnitude > 0.001 then
							local position = gameCamera.CFrame.Position
							gameCamera.CFrame = CFrame.lookAt(position, position + look.Unit)
						end
					until alpha >= 1 or not entitylib.isAlive
					if not entitylib.isAlive then
						if visual then
							visual:Destroy()
						end
						return
					end
					cannon.AimPrompt:InputHoldBegin()
					task.wait(cannon.AimPrompt.HoldDuration)
	
					local ready = tick() + 1
					repeat
						runService.PostSimulation:Wait()
					until cannon.StopAimingPrompt.Enabled or tick() > ready or not cannon.Parent
	
					cannon.StopAimingPrompt:InputHoldBegin()
				end
				task.wait((cannon.StopAimingPrompt.HoldDuration + (0.2 + store.ping.total)) + runService.PostSimulation:Wait())
	
				if Mode.Value == 'Legit' then
					local success, aiming = pcall(function()
						return bedwars.CannonController:isAiming()
					end)
					if success and aiming then
						pcall(function()
							bedwars.CannonController:stopAiming()
						end)
					end
				end
	
				local blockPosition = bedwars.BlockController:getBlockPosition(cannon.Position)
				local aimed
				local timeout = tick() + 1
				repeat
					bedwars.Handler:Get('AimCannon'):Fire('SendToServer', {
						cannonBlockPos = blockPosition,
						lookVector = launchDirection
					})
					task.wait(0.15)
					local look = cannon:GetAttribute('LookVector')
					aimed = look and (look - launchDirection).Magnitude < 0.0001
				until aimed or tick() > timeout or not cannon.Parent
	
				if not aimed then
					notif('DaveyAim', 'Cannon refused the aim.', 5, 'warning')
					if visual then
						visual:Destroy()
					end
					return
				end
	
				if LaunchCannon.Enabled then
					if Mode.Value == 'Legit' then
						cannon.LaunchSelfPrompt:InputHoldBegin()
						task.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
					else
						bedwars.CannonHandController:launchSelf(cannon)
					end
				else
					local launched, aimed = false, true
					local connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
						if plr == lplr then
							launched = true
						end
					end)
					local timeout = tick() + 30
	
					repeat
						runService.PostSimulation:Wait()
						local look = cannon.Parent and cannon:GetAttribute('LookVector')
						aimed = typeof(look) ~= 'Vector3' or (look - launchDirection).Magnitude < 0.0001
					until launched or not aimed or tick() > timeout or not entitylib.isAlive or not cannon.Parent
	
					connection:Disconnect()
					if not launched then
						if not aimed then
							notif('DaveyAim', 'Cannon was re-aimed before you launched.', 5, 'warning')
						end
						if visual then
							visual:Destroy()
						end
						return
					end
				end
	
				local flightStart, flightOrigin = tick(), localPosition
				local flightVelocity = (((target - localPosition) + Vector3.new(0, workspace.Gravity * time * time * 0.5, 0)) / time - velocity) + velocity
				local landing = tick() + time
				local root
				repeat
					runService.PreSimulation:Wait()
					root = entitylib.isAlive and entitylib.character.RootPart
					if root then
						local elapsed = math.clamp(tick() - flightStart, 0, time)
						local drop = workspace.Gravity * elapsed * elapsed * 0.5
						local idealPosition = flightOrigin + (flightVelocity * elapsed) - Vector3.new(0, drop, 0)
						local idealVelocity = flightVelocity - Vector3.new(0, workspace.Gravity * elapsed, 0)
						local ceiling = math.sqrt((cannonSpeed * cannonSpeed) + (2 * workspace.Gravity * math.max(flightOrigin.Y - root.Position.Y, 0)))
						local corrected = idealVelocity + ((idealPosition - root.Position) * 6)
						root.AssemblyLinearVelocity = corrected.Magnitude > ceiling and corrected.Unit * ceiling or corrected
						if visual then
							visual.Tag.TextLabel.Text = `Landing ({math.floor((target - root.Position).Magnitude)} studs)`
						end
					end
				until not root or tick() > landing
	
				local settle, grounded = tick() + 0.5, false
				repeat
					runService.PreSimulation:Wait()
					root = entitylib.isAlive and entitylib.character.RootPart
					if root then
						root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						grounded = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
					end
				until not root or grounded or tick() > settle
	
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local velocity = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(0, math.min(velocity.Y, 0), 0)
				end
	
				if visual then
					visual:Destroy()
				end
			end
		end,
		Tooltip = 'Aims a nearby cannon at your cursor and launches you onto it'
	})
	
	Mode = DaveyAim:CreateDropdown({
		Name = 'Aim Mode',
		List = {'Blatant', 'Legit'},
		Default = 'Blatant'
	})
	Position = DaveyAim:CreateDropdown({
		Name = 'Position Mode',
		List = {'Mouse', 'Camera'},
		Default = 'Mouse'
	})
	Range = DaveyAim:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 18,
		Default = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	PlaceCannon = DaveyAim:CreateToggle({
		Name = 'Place Cannon',
		Function = function(callback)
			if Switch then
				Switch.Object.Visible = callback
			end
		end,
		Tooltip = 'Puts a cannon down on the nearest free block when there is none in range',
		Default = true
	})
	Switch = DaveyAim:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Darker = true,
		Tooltip = 'Holds the cannon before placing it'
	})
	LaunchCannon = DaveyAim:CreateToggle({
		Name = 'Launch Cannon',
		Default = true,
		Tooltip = 'Launches you itself, turn this off to aim only and still land on target when you launch yourself'
	})
	ShowTarget = DaveyAim:CreateToggle({
		Name = 'Show Target',
		Default = true,
		Tooltip = 'Highlights the block you are landing on until you land'
	})
end)

run(function()
	local EquipKit
	local Kit
	
	local old = {}
	
	EquipKit = vape.Categories.Kits:CreateModule({
		Name = 'EquipKit',
		Function = function(callback)
			if callback then
				EquipKit:Toggle()
				notif('EquipKit', `{bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = old[Kit.Value]}) and 'Successfully equipped' or 'Failed to equip'} {Kit.Value}.`, 10, 'info')
			end
		end
	})
	
	local list = {}
	for i, v in bedwars.BedwarsKitMeta do
		table.insert(list, v.name)
		old[v.name] = i
	end
	table.sort(list)
	Kit = EquipKit:CreateDropdown({
		Name = 'Equip kit',
		List = list,
		Default = 'None'
	})
end)

run(function()
	local FalconAura
	local Range
	local Delay
	local Recall
	local nextSend = 0
	
	FalconAura = vape.Categories.Kits:CreateModule({
		Name = 'FalconAura',
		Function = function(callback)
			if callback then
				nextSend = 0
	
				repeat
					if entitylib.isAlive and store.equippedKit == 'falconer' and tick() >= nextSend then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
	
						if target and bedwars.AbilityController:canUseAbility('SEND_FALCON', {disableBlockedAbilityAlert = true}) then
							nextSend = tick() + Delay.Value
							bedwars.AbilityController:useAbility('SEND_FALCON')
						elseif not target and Recall.Enabled and bedwars.AbilityController:canUseAbility('RECALL_FALCON', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('RECALL_FALCON')
						end
					end
					task.wait(0.1)
				until not FalconAura.Enabled
			end
		end,
		Tooltip = 'Automatically sends Bekzat falcon at whoever is near you'
	})
	
	Range = FalconAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 80,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = FalconAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Recall = FalconAura:CreateToggle({
		Name = 'Recall when clear',
		Default = true,
		Tooltip = 'Calls the falcon back once nobody is in range'
	})
end)

run(function()
	local FishermanSpy
	local Teammates
	
	FishermanSpy = vape.Categories.Kits:CreateModule({
		Name = 'FishermanSpy',
		Function = function(call)
			if call then
				FishermanSpy:Clean(bedwars.Handler:Get('FishCaught').Remote:Connect(function(data)
					if data.dropData and data.dropData.drops and data.catchingPlayer and (not Teammates.Enabled or lplr.Team ~= data.catchingPlayer.Team) then
						local text = {}
						for _, v in data.dropData.drops do
							local itemmeta = bedwars.ItemMeta[v.itemType]
							table.insert(text, `{v.amount} {(itemmeta and itemmeta.displayName or v.itemType):lower()}{v.amount >= 2 and 's' or ''}`)
						end
	
						if #text > 0 then
							notif('FishermanSpy', `{data.catchingPlayer.Name} caught {table.concat(text, ', ')}`, 20, 'info')
						end
					end
				end))
			end
		end,
		Tooltip = 'Notifies you whenever someone reels in a fish, and what it dropped'
	})
	
	Teammates = FishermanSpy:CreateToggle({
		Name = 'Ignore teammate',
		Default = true
	})
end)

run(function()
	local old
	
	vape.Categories.Kits:CreateModule({
		Name = 'InfiniteKrystal',
		Function = function(call)
			if call then
				old = bedwars.GlacialSkaterController.updateMomentum
				bedwars.GlacialSkaterController.updateMomentum = function(self, ...)
					self.momentum = 1000
					self.lastMomentumReport = workspace:GetServerTimeNow()
					return old(self, ...)
				end
			else
				bedwars.GlacialSkaterController.updateMomentum = old
			end
		end,
		Tooltip = 'Gives you max momentum forever'
	})
end)

run(function()
	local KitExtender
	local Kaida
	local KaidaRange
	local olds = {}
	local summonrange
	
	local boosts = {
		{
			Name = 'Jade Hammer',
			Kit = 'jade',
			Controller = 'JadeHammerController',
			Method = 'useJadeHammer',
			Tooltip = 'Extends how far the Jade Hammer jump launches you',
			Hook = function(entry, old)
				return function(self)
					local jumped = bedwars.AbilityController:canUseAbility('jade_hammer_jump', {disableBlockedAbilityAlert = true})
					local call = old(self)
	
					if entry.Toggle.Enabled and jumped and store.equippedKit == 'jade' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (entry.Multiplier.Value - 1) * 20.5, 0))
					end
					return call
				end
			end
		},
		{
			Name = 'Void Regent Dash',
			Kit = 'regent',
			Controller = 'VoidAxeController',
			Method = 'useVoidAxe',
			Tooltip = 'Extends how far the Void Regent axe dash launches you',
			Hook = function(entry, old)
				return function(self)
					local dashed = bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true})
					local call = old(self)
	
					if entry.Toggle.Enabled and dashed and store.equippedKit == 'regent' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(root.CFrame.LookVector * Vector3.new(1, 0, 1) * root.AssemblyMass * (entry.Multiplier.Value - 1) * 70)
					end
					return call
				end
			end
		},
		{
			Name = 'Yamini Pounce',
			Kit = 'cat',
			Controller = 'CatController',
			Method = 'leap',
			Tooltip = 'Extends how far the Yamini pounce launches you',
			Hook = function(entry, old)
				return function(self, character, direction)
					local call = old(self, character, direction)
					local horizontal = direction and direction * Vector3.new(1, 0, 1) or Vector3.zero
					local root = character and character:FindFirstChild('HumanoidRootPart')
					if entry.Toggle.Enabled and store.equippedKit == 'cat' and root and horizontal.Magnitude > 0 then
						root:ApplyImpulse(horizontal.Unit * root.AssemblyMass * (entry.Multiplier.Value - 1) * 70)
					end
					return call
				end
			end
		},
		{
			Name = 'Yamini Wall Kick',
			Kit = 'cat',
			Controller = 'CatController',
			Method = 'dismountWall',
			Tooltip = 'Extends how high dropping off a climbed wall throws you',
			Hook = function(entry, old)
				return function(self, ...)
					local call = old(self, ...)
	
					if entry.Toggle.Enabled and store.equippedKit == 'cat' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (entry.Multiplier.Value - 1) * 25, 0))
					end
					return call
				end
			end
		},
		{
			Name = 'Yuzi Dash',
			Kit = 'dasher',
			Controller = 'DaoController',
			Method = 'dashForward',
			Tooltip = 'Extends how far the yuzi dash launches you',
			Hook = function(entry, old)
				return function(self, direction)
					local call = old(self, direction)
					local horizontal = direction and direction * Vector3.new(1, 0, 1) or Vector3.zero
					if entry.Toggle.Enabled and store.equippedKit == 'dasher' and entitylib.isAlive and horizontal.Magnitude > 0 then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(horizontal.Unit * root.AssemblyMass * (entry.Multiplier.Value - 1) * 70)
					end
					return call
				end
			end
		},
		{
			Name = 'Xurot Wing Flap',
			Kit = 'void_dragon',
			Controller = 'VoidDragonController',
			Method = 'flapWings',
			Tooltip = 'Extends how high each wing flap throws you',
			Hook = function(entry, old)
				return function(self, ...)
					local call = old(self, ...)
	
					if entry.Toggle.Enabled and store.equippedKit == 'void_dragon' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (entry.Multiplier.Value - 1) * 40, 0))
					end
					return call
				end
			end
		}
	}
	
	KitExtender = vape.Categories.Kits:CreateModule({
		Name = 'KitExtender',
		Function = function(callback)
			if callback then
				for i, v in boosts do
					local controller = bedwars[v.Controller]
					if controller and controller[v.Method] then
						olds[i] = controller[v.Method]
						controller[v.Method] = v.Hook(v, olds[i])
					end
				end
	
				if Kaida.Enabled then
					local suc, balance = pcall(function()
						return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance
					end)
					if suc and balance then
						summonrange = summonrange or balance.SPELL_CAST_RANGE
						balance.SPELL_CAST_RANGE = math.max(KaidaRange.Value, summonrange)
					end
				end
			else
				for i, v in boosts do
					local controller = bedwars[v.Controller]
					if controller and olds[i] then
						controller[v.Method] = olds[i]
					end
				end
				table.clear(olds)
	
				if summonrange then
					local suc, balance = pcall(function()
						return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance
					end)
					if suc and balance then
						balance.SPELL_CAST_RANGE = summonrange
					end
					summonrange = nil
				end
			end
		end,
		Tooltip = 'Pushes kit movement abilities further than the game intends'
	})
	
	for _, v in boosts do
		v.Toggle = KitExtender:CreateToggle({
			Name = v.Name,
			Function = function(callback)
				if v.Multiplier and v.Multiplier.Object then
					v.Multiplier.Object.Visible = callback
				end
			end,
			Tooltip = v.Tooltip
		})
		v.Multiplier = KitExtender:CreateSlider({
			Name = `{v.Name} multiplier`,
			Min = 1,
			Max = 5,
			Decimal = 10,
			Default = 2,
			Darker = true,
			Visible = false,
			Suffix = 'x'
		})
	end
	Kaida = KitExtender:CreateToggle({
		Name = 'Kaida Summon Range',
		Function = function(callback)
			if KaidaRange and KaidaRange.Object then
				KaidaRange.Object.Visible = callback
			end
			if KitExtender.Enabled then
				KitExtender:Toggle()
				KitExtender:Toggle()
			end
		end,
		Tooltip = 'Lifts the cap the game puts on where the summon circle can land'
	})
	KaidaRange = KitExtender:CreateSlider({
		Name = 'Kaida summon range',
		Min = 45,
		Max = 120,
		Function = function(value)
			if not KitExtender.Enabled or not summonrange then return end
			local suc, balance = pcall(function()
				return require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance
			end)
			if suc and balance then
				balance.SPELL_CAST_RANGE = math.max(value, summonrange)
			end
		end,
		Default = 75,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoPickpocket
	local Targets
	local Range
	local Hidden
	
	local Legit = getFunctionRange(bedwars.MimicController.onKitLocalActivated) or 25
	local mimicPickPocket = bedwars.Handler:Get('MimicBlockPickPocketPlayer')
	local sounds = {bedwars.SoundList.MIMIC_PICKPOCKET_1, bedwars.SoundList.MIMIC_PICKPOCKET_2, bedwars.SoundList.MIMIC_PICKPOCKET_3}
	local random = Random.new()
	
	AutoPickpocket = vape.Categories.Kits:CreateModule({
		Name = 'AutoPickpocket',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local targets = entitylib.AllPosition({
							Range = Range.Value,
							Origin = localPosition,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Distance
						})
	
						for _, v in targets do
							if mimicPickPocket:Fire('CallServer', v.Player) then
								bedwars.AudioManager:playAudio(sounds[random:NextInteger(1, #sounds)], {
									playbackSpeedMultiplier = 1.27,
									position = localPosition
								})
							end
						end
	
						if #targets <= 0 and Hidden.Enabled and store.equippedKit == 'mimic' and bedwars.AbilityController:canUseAbility('MIMIC_BLOCK_HIDDEN', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('MIMIC_BLOCK_HIDDEN')
						end
					end
					task.wait(0.1)
				until not AutoPickpocket.Enabled
			end
		end,
		Tooltip = 'Automatically pickpockets with milo kit.'
	})
	
	Targets = AutoPickpocket:CreateTargets({Players = true, Walls = true})
	
	Range = AutoPickpocket:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = Legit,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoPickpocket:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Hidden = AutoPickpocket:CreateToggle({
		Name = 'Hide when clear',
		Tooltip = 'Goes back into the block once nobody is in range'
	})
end)

run(function()
	local RavenTP
	
	RavenTP = vape.Categories.Kits:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('raven') and plr then
					bedwars.Handler:Get('SpawnRaven'):Fire('CallServerAsync'):andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart
	
							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
	})
end)

run(function()
	local VoidRegentAutoClutch
	local Range
	local Depth
	local FallSpeed
	local FaceGround
	local lastClutch = 0
	
	VoidRegentAutoClutch = vape.Categories.Kits:CreateModule({
		Name = 'VoidRegentAutoClutch',
		Function = function(callback)
			if callback then
				VoidRegentAutoClutch:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive and store.equippedKit == 'regent' and store.airRay and tick() >= lastClutch and bedwars.VoidAxeController then
						local root = entitylib.character.RootPart
						if root.AssemblyLinearVelocity.Y < -FallSpeed.Value and not entitylib.Raycast(root.Position, Vector3.new(0, -Depth.Value, 0), store.airRay) and bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true}) then
							local ground = getNearGround(Range.Value / 3)
							local delta = ground and (ground - root.Position) * Vector3.new(1, 0, 1)
							if delta and delta.Magnitude > 0 then
								lastClutch = tick() + 0.5
								if FaceGround.Enabled then
									root.CFrame = CFrame.lookAt(root.Position, root.Position + delta.Unit)
								end
								bedwars.VoidAxeController:useVoidAxe()
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Dashes the void axe back towards solid ground when you fall off the map'
	})
	
	Range = VoidRegentAutoClutch:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 45,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far to look for ground to dash back to'
	})
	Depth = VoidRegentAutoClutch:CreateSlider({
		Name = 'Depth',
		Min = 10,
		Max = 150,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Nothing beneath you within this counts as the void'
	})
	FallSpeed = VoidRegentAutoClutch:CreateSlider({
		Name = 'Fall speed',
		Min = 0,
		Max = 100,
		Default = 10,
		Tooltip = 'Only clutches once you are dropping this fast'
	})
	FaceGround = VoidRegentAutoClutch:CreateToggle({
		Name = 'Face ground',
		Default = true,
		Tooltip = 'Turns you towards the ground first, the dash always goes where you face'
	})
end)

run(function()
	local VulcanAssist
	local Targets
	local Range
	local Sort
	
	VulcanAssist = vape.Categories.Kits:CreateModule({
		Name = 'VulcanAssist',
		Function = function(callback)
			if callback then
				repeat
					local turret = entitylib.isAlive and bedwars.Store:getState().Game.selectedTurret
					if turret then
						local origin = turret.Rotate.Position
						local ent = entitylib.EntityMouse({
							Range = Range.Value,
							Origin = origin,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Priority = Targets.Priority.Value,
							Sort = sortmethods[Sort.Value]
						})
						local pos = ent and prediction.SolveTrajectory(origin, 320, 10, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, nil, store.airRay, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart)
						if pos then
							local delta = pos - origin
							bedwars.TurretCameraController.angleX = math.atan2(-delta.X, -delta.Z)
							bedwars.TurretCameraController.angleY = math.clamp(math.atan2(delta.Y, math.sqrt(delta.X ^ 2 + delta.Z ^ 2)), -0.8, 0.8)
						end
					end
					task.wait(0.1)
				until not VulcanAssist.Enabled
			end
		end,
		Tooltip = 'Automatically aims turret camera toward opponents'
	})
	
	Targets = VulcanAssist:CreateTargets({Walls = true, Players = true})
	
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	
	Sort = VulcanAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = methods[1]
	})
	Range = VulcanAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 500
	})
end)

run(function()
	local BedBreakEffect
	local List
	local NameToId = {}
	
	BedBreakEffect = vape.Legit:CreateModule({
		Name = 'Bed Break Effect',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_bedbreakeffect.png'),
		Function = function(callback)
			if callback then
				BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
					firesignal(bedwars.Handler:Get('BedBreakEffectTriggered').Remote.instance.OnClientEvent, {
						player = data.player,
						position = data.bedBlockPosition * 3,
						effectType = NameToId[List.Value],
						teamId = data.brokenBedTeam.id,
						centerBedPosition = data.bedBlockPosition * 3
					})
				end))
			end
		end,
		Tooltip = 'Custom bed break effects'
	})
	
	local BreakEffectName = {}
	for i, v in bedwars.BedBreakEffectMeta do
		table.insert(BreakEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(BreakEffectName)
	List = BedBreakEffect:CreateDropdown({
		Name = 'Effect',
		List = BreakEffectName
	})
end)

run(function()
	local old
	
	vape.Legit:CreateModule({
		Name = 'Clean Kit',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_cleankit.png'),
		Function = function(callback)
			if callback then
				old = bedwars.WindWalkerController.spawnOrb
				bedwars.WindWalkerController.spawnOrb = function() end
				local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
				if zephyreffect then
					zephyreffect.Visible = false
				end
			else
				bedwars.WindWalkerController.spawnOrb = old
			end
		end,
		Tooltip = 'Removes zephyr status indicator'
	})
end)

run(function()
	local old
	local Image
	local foundids
	
	local Crosshair = vape.Legit:CreateModule({
		Name = 'Crosshair',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_crosshair.png'),
		Function = function(callback)
			if callback then
				if not foundids then
					foundids = {}
					for i, v in debug.getconstants(bedwars.ViewmodelController.showCrosshair) do
						if tostring(v):find('rbxassetid://') then
							table.insert(foundids, i)
						end
					end
	
					if #foundids == 0 then
						foundids = nil
						return warn('[KingVape] Crosshair failed to get constants')
					end
				end
	
				old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, foundids[1])
				for _, v in foundids do
					debug.setconstant(bedwars.ViewmodelController.showCrosshair, v, Image.Value)
				end
			elseif foundids then
				for _, v in foundids do
					debug.setconstant(bedwars.ViewmodelController.showCrosshair, v, old)
				end
			end
	
			if bedwars.ViewmodelController.crosshair then
				bedwars.ViewmodelController:hideCrosshair()
				bedwars.ViewmodelController:showCrosshair()
			end
		end,
		Tooltip = 'Custom first person crosshair depending on the image choosen.'
	})
	
	Image = Crosshair:CreateTextBox({
		Name = 'Image',
		Placeholder = 'image id (roblox)',
		Function = function(enter)
			if enter and Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end
	})
end)

run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke
	local suc, tab = pcall(function()
		return debug.getupvalue(bedwars.DamageIndicator, 2)
	end)
	tab = suc and tab or {}
	local oldvalues, oldfont = {}
	
	local cache = {}
	
	local function dumpConstant(search)
		if cache[search] then
			return cache[search]
		end
	
		for i, v in debug.getconstants(bedwars.DamageIndicator) do
			if v and tostring(v):find(search) then
				cache[search] = i
				return i
			end
		end
		return nil
	end
	
	DamageIndicator = vape.Legit:CreateModule({
		Name = 'Damage Indicator',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_damageindicator.png'),
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfont = debug.getconstant(bedwars.DamageIndicator, dumpConstant('Enum.Font'))
				debug.setconstant(bedwars.DamageIndicator, dumpConstant('Enum.Font'), Enum.Font[FontOption.Value])
				debug.setconstant(bedwars.DamageIndicator, dumpConstant('Thickness'), Stroke.Enabled and 'Thickness' or 'Enabled')
				tab.strokeThickness = Stroke.Enabled and 1 or false
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				debug.setconstant(bedwars.DamageIndicator, dumpConstant('Enum.Font'), oldfont)
				debug.setconstant(bedwars.DamageIndicator, dumpConstant('Thickness'), 'Thickness')
			end
		end,
		Tooltip = 'Customize the damage indicator'
	})
	
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, dumpConstant('Enum.Font'), Enum.Font[val])
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end,
		Default = 32
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, dumpConstant('Thickness'), callback and 'Thickness' or 'Enabled')
				tab.strokeThickness = callback and 1 or false
			end
		end
	})
end)

run(function()
	local FOV
	local Value
	local old, old2
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_fov.png'),
		Function = function(callback)
			if callback then
				old = bedwars.FovController.setFOV
				old2 = bedwars.FovController.getFOV
				bedwars.FovController.setFOV = function(self)
					return old(self, Value.Value)
				end
				bedwars.FovController.getFOV = function()
					return Value.Value
				end
			else
				bedwars.FovController.setFOV = old
				bedwars.FovController.getFOV = old2
			end
	
			bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
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
	local cap = getfpscap and getfpscap() or nil
	
	vape.Legit:CreateModule({
		Name = 'FPSUnlocker',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_fpsunlocker.png'),
		Function = function(callback)
			if cap then
				setfpscap(callback and 9999 or cap)
			elseif callback then
				setfpscap(9999)
				notif('FPSUnlocker', 'You have to restart ur game inorder to disable this.', 8, 'info')
			end
		end
	})
end)

run(function()
	local HitColor
	local Color
	local done = {}
	
	HitColor = vape.Legit:CreateModule({
		Name = 'Hit Color',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_hitcolor.png'),
		Function = function(callback)
			if callback then
				repeat
					for _, v in entitylib.List do
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then
							if not table.find(done, highlight) then
								table.insert(done, highlight)
							end
							highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
							highlight.FillTransparency = Color.Opacity
						end
					end
					task.wait(0.1)
				until not HitColor.Enabled
			else
				for _, v in done do
					v.FillColor = Color3.new(1, 0, 0)
					v.FillTransparency = 0.4
				end
				table.clear(done)
			end
		end,
		Tooltip = 'Customize the hit highlight options'
	})
	
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)

run(function()
	vape.Legit:CreateModule({
		Name = 'HitFix',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_hitfix.png'),
		Function = function(callback)
			debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
			debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
		end,
		Tooltip = 'Changes the raycast function to the correct one'
	})
end)

run(function()
	local Interface
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local old, new = {}, {}
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val
	
		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	Interface = vape.Legit:CreateModule({
		Name = 'Interface',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_interface.png'),
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
		end,
		Tooltip = 'Customize bedwars UI'
	})
	
	local fontitems = {'LuckiestGuy'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'LuckiestGuy' then
			table.insert(fontitems, v.Name)
		end
	end
	Interface:CreateDropdown({
		Name = 'Health Font',
		List = fontitems,
		Function = function(val)
			modifyconstant(HotbarHealthbar.render, 77, val)
		end
	})
	Interface:CreateColorSlider({
		Name = 'Health Color',
		Function = function(hue, sat, val)
			modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			if Interface.Enabled then
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
				if hotbar then
					hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			end
		end
	})
	Interface:CreateColorSlider({
		Name = 'Hotbar Color',
		DefaultOpacity = 0.8,
		Function = function(hue, sat, val, opacity)
			local func = oldinvrender or HotbarOpenInventory.render
			local render = debug.getupvalue(HotbarApp, 23).render
			modifyconstant(render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			modifyconstant(render, 54, 1 - opacity)
			modifyconstant(render, 55, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		end
	})
end)

run(function()
	local KillEffect
	local Mode
	local List
	local NameToId = {}
	local debrisService = cloneref(game:GetService('Debris'))
	
	local killeffects = {
		Gravity = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			local nametag = char:FindFirstChild('Nametag', true)
			if highlight then
				highlight:Destroy()
			end
			if nametag then
				nametag:Destroy()
			end
	
			task.spawn(function()
				local partvelo = {}
				for _, v in char:GetDescendants() do
					if v:IsA('BasePart') then
						partvelo[v.Name] = v.AssemblyLinearVelocity
					end
				end
				char.Archivable = true
				local clone = char:Clone()
				clone.Humanoid.Health = 100
				clone.Parent = workspace
				debrisService:AddItem(clone, 30)
				char:Destroy()
				task.wait(0.01)
				clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				clone:BreakJoints()
				task.wait(0.01)
				for _, v in clone:GetDescendants() do
					if v:IsA('BasePart') then
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
						bodyforce.Parent = v
						v.CanCollide = true
						v.AssemblyLinearVelocity = partvelo[v.Name] or Vector3.zero
					end
				end
			end)
		end,
		Lightning = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			if highlight then
				highlight:Destroy()
			end
			local startpos = 1125
			local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
			local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)
	
			for i = startpos - 75, 0, -75 do
				local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
				if i == 0 then
					newpos2 = Vector3.zero
				end
				local part = Instance.new('Part')
				part.Size = Vector3.new(1.5, 1.5, 77)
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored = true
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
				part.Parent = workspace
				local part2 = part:Clone()
				part2.Size = Vector3.new(3, 3, 78)
				part2.Color = Color3.new(0.7, 0.7, 0.7)
				part2.Transparency = 0.7
				part2.Material = Enum.Material.SmoothPlastic
				part2.Parent = workspace
				debrisService:AddItem(part, 0.5)
				debrisService:AddItem(part2, 0.5)
				bedwars.QueryUtil:setQueryIgnored(part, true)
				bedwars.QueryUtil:setQueryIgnored(part2, true)
				if i == 0 then
					local soundpart = Instance.new('Part')
					soundpart.Transparency = 1
					soundpart.Anchored = true
					soundpart.Size = Vector3.zero
					soundpart.Position = startcf
					soundpart.Parent = workspace
					bedwars.QueryUtil:setQueryIgnored(soundpart, true)
					local sound = Instance.new('Sound')
					sound.SoundId = 'rbxassetid://6993372814'
					sound.Volume = 2
					sound.Pitch = 0.5 + (math.random(1, 3) / 10)
					sound.Parent = soundpart
					sound:Play()
					sound.Ended:Connect(function()
						soundpart:Destroy()
					end)
				end
				newpos = newpos2
			end
		end,
		Delete = function(_, _, char, _)
			char:Destroy()
		end
	}
	
	KillEffect = vape.Legit:CreateModule({
		Name = 'Kill Effect',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_killeffect.png'),
		Function = function(callback)
			if callback then
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = {
						new = function()
							return {
								onKill = v,
								isPlayDefaultKillEffect = function()
									return false
								end
							}
						end
					}
				end
				KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
					lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
				end))
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			else
				for i in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = nil
				end
				lplr:SetAttribute('KillEffectType', 'default')
			end
		end,
		Tooltip = 'Custom final kill effects'
	})
	
	local modes = {'Bedwars'}
	for i in killeffects do
		table.insert(modes, i)
	end
	Mode = KillEffect:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Function = function(val)
			if List then
				List.Object.Visible = val == 'Bedwars'
			end
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
			end
		end
	})
	local KillEffectName = {}
	for i, v in bedwars.KillEffectMeta do
		table.insert(KillEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(KillEffectName)
	List = KillEffect:CreateDropdown({
		Name = 'Bedwars',
		List = KillEffectName,
		Function = function(val)
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', NameToId[val])
			end
		end,
		Darker = true
	})
end)

run(function()
	local Ping
	local label

	Ping = vape.Legit:CreateModule({
		Name = 'Ping',
		Category = 'HUD',
		Icon = getvapeasset('catsix/assets/new/legit_ping.png'),
		Function = function(callback)
			if callback then
				repeat
					label.Text = math.floor(math.max(store.ping.incoming or 0, store.ping.total or 0) * 1000)..' ms'
					task.wait(0.1)
				until not Ping.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41),
		Tooltip = 'Shows the current connection speed to the game server'
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
task.spawn(function()
	local incoming
	repeat
		if not incoming then
			incoming = os.clock()
			task.spawn(function()
				bedwars.Handler:Get('TridentUnanchor'):Fire('CallServer')
				store.ping.total = os.clock() - incoming
				incoming = nil
			end)
		end
		store.ping.incoming = os.clock() - incoming
		task.wait(1)
	until vape.Loaded == nil
end)

run(function()
	local PotionStatus
	local ShowPositive
	local ShowNegative
	local Background
	local BackgroundColor
	local effects = {}
	local seen = {}
	local replacements = {
		speed = 'rbxassetid://71873445837330'
	}
	local negative = {
		bleed = true,
		burn = true,
		cold = true,
		curse_of_the_altar = true,
		decay = true,
		dizzy = true,
		feeble = true,
		frost_bite = true,
		frosted = true,
		frozen = true,
		grave_trap = true,
		greased = true,
		grounded = true,
		grounded_enchant = true,
		hungry = true,
		infected_poison = true,
		isabel_shield_broken = true,
		lunar_venom = true,
		mage_burn = true,
		oil_spilled = true,
		oiled = true,
		on_ice = true,
		owl_target = true,
		poison = true,
		powdered = true,
		shield_down = true,
		shrink = true,
		silas_halloween_hex = true,
		silence = true,
		skeleton_poison = true,
		snae_poison_arrow = true,
		snake_poison_sword = true,
		soaked = true,
		SPIDER_WEB_SLOW = true,
		stacking_decay = true,
		Vengeful_venom = true,
		void_hunter_marked = true,
		weak_armor = true,
		werewolf_fear = true,
		zapped_1 = true,
		zapped_2 = true,
		zapped_3 = true
	}
	local accentcolor = Color3.fromRGB(5, 134, 105)
	local warncolor = Color3.fromRGB(236, 129, 44)
	local dangercolor = Color3.fromRGB(250, 50, 56)
	local halfcut = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1)
	})
	local background
	
	local function Added(active)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		effects[active.statusEffect] = active.expireTime
		local max = active.expireTime - workspace:GetServerTimeNow()
		if max <= 0 then
			effects[active.statusEffect] = nil
			return
		end
	
		local meta = bedwars.ItemMeta[active.statusEffect] or bedwars.ItemMeta[active.statusEffect..'_potion']
		local effect = Instance.new('Frame')
		effect.BackgroundTransparency = 1
		effect.Parent = background
		local ring = Instance.new('Frame')
		ring.BackgroundTransparency = 1
		ring.Position = UDim2.fromOffset(0, 4)
		ring.Size = UDim2.fromOffset(50, 50)
		ring.Parent = effect
		local backing = Instance.new('Frame')
		backing.BackgroundTransparency = 1
		backing.Position = UDim2.fromOffset(4.5, 4.5)
		backing.Size = UDim2.fromOffset(41, 41)
		backing.Parent = ring
		local backingcorner = Instance.new('UICorner')
		backingcorner.CornerRadius = UDim.new(1, 0)
		backingcorner.Parent = backing
		local backingstroke = Instance.new('UIStroke')
		backingstroke.Color = Color3.new()
		backingstroke.Thickness = 3.6
		backingstroke.Transparency = 0.216
		backingstroke.Parent = backing
		local gradients, strokes = {}, {}
	
		for _, v in {'Left', 'Right'} do
			local clip = Instance.new('Frame')
			clip.BackgroundTransparency = 1
			clip.ClipsDescendants = true
			clip.Position = UDim2.fromOffset(v == 'Right' and 25 or 0, 0)
			clip.Size = UDim2.fromOffset(25, 50)
			clip.Parent = ring
			local arc = Instance.new('Frame')
			arc.BackgroundTransparency = 1
			arc.Position = UDim2.fromOffset(v == 'Right' and -21 or 4, 4)
			arc.Size = UDim2.fromOffset(42, 42)
			arc.Parent = clip
			local arccorner = Instance.new('UICorner')
			arccorner.CornerRadius = UDim.new(1, 0)
			arccorner.Parent = arc
			local arcstroke = Instance.new('UIStroke')
			arcstroke.Color = accentcolor
			arcstroke.Thickness = 4
			arcstroke.Parent = arc
			local arcgradient = Instance.new('UIGradient')
			arcgradient.Transparency = halfcut
			arcgradient.Parent = arcstroke
			gradients[v] = arcgradient
			strokes[v] = arcstroke
		end
	
		local sidebar = Instance.new('Frame')
		sidebar.AnchorPoint = Vector2.new(0, 0.5)
		sidebar.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
		sidebar.BackgroundTransparency = 0.5
		sidebar.BorderSizePixel = 0
		sidebar.Position = UDim2.new(0, 53, 0.5, 1)
		sidebar.Size = UDim2.fromOffset(2, 27)
		sidebar.Parent = effect
		local effectimage = Instance.new('ImageLabel')
		effectimage.AnchorPoint = Vector2.new(0, 0.5)
		effectimage.BackgroundTransparency = 1
		effectimage.Image = replacements[active.statusEffect] or (meta and meta.image) or bedwars.ImageList.POTION_ART
		effectimage.Position = UDim2.new(0, 10, 0.5, 0)
		effectimage.Size = UDim2.fromOffset(30, 30)
		effectimage.Parent = effect
		local effectname = Instance.new('TextLabel')
		effectname.BackgroundTransparency = 1
		effectname.FontFace = uipallet.FontBold
		effectname.Position = UDim2.fromOffset(67, 10)
		effectname.Size = UDim2.fromOffset(108, 20)
		effectname.Text = (active.statusEffect:sub(0, 1):upper()..active.statusEffect:sub(2, #active.statusEffect)):gsub('_', ' ')
		effectname.TextColor3 = Color3.new(1, 1, 1)
		effectname.TextSize = 15
		effectname.TextXAlignment = Enum.TextXAlignment.Left
		effectname.Parent = effect
		local nameshadow = effectname:Clone()
		nameshadow.Position += UDim2.fromOffset(1, 1)
		nameshadow.TextColor3 = Color3.new()
		nameshadow.TextTransparency = 0.5
		nameshadow.ZIndex = 0
		nameshadow.Parent = effect
		effect.Size = UDim2.fromOffset(getfontbounds(effectname.Text, 15, uipallet.FontBold).X + 80, 57)
		local effectduration = effectname:Clone()
		effectduration.Position = UDim2.fromOffset(67, 29)
		effectduration.Text = '00:00'
		effectduration.TextSize = 14
		effectduration.Parent = effect
		local durationshadow = effectduration:Clone()
		durationshadow.Position += UDim2.fromOffset(1, 1)
		durationshadow.TextColor3 = Color3.new()
		durationshadow.TextTransparency = 0.5
		durationshadow.ZIndex = 0
		durationshadow.Parent = effect
		local secs = 0
	
		repeat
			local remaining = math.max(active.expireTime - workspace:GetServerTimeNow(), 0)
			local percent = remaining / max
			local ringcolor = percent > 0.5 and accentcolor or (percent > 0.25 and warncolor or dangercolor)
			local theta = math.min(percent, 1) * 360
			secs = math.floor(remaining)
			gradients.Left.Rotation = math.clamp(theta, 180, 360)
			gradients.Right.Rotation = math.clamp(theta, 0, 180)
			strokes.Left.Color = ringcolor
			strokes.Right.Color = ringcolor
			effectduration.Text = ('%02d:%02d'):format(secs // 60, secs % 60)
			effectduration.TextColor3 = ringcolor
			durationshadow.Text = effectduration.Text
			task.wait()
		until secs <= 0 or effects[active.statusEffect] ~= active.expireTime
	
		effect:Destroy()
	
		if effects[active.statusEffect] == active.expireTime then
			effects[active.statusEffect] = nil
		end
	end
	
	PotionStatus = vape.Legit:CreateModule({
		Name = 'Potion Status',
		Category = 'HUD',
		Icon = getvapeasset('catsix/assets/new/legit_potionstatus.png'),
		Function = function(callback)
			if callback then
				repeat
					table.clear(seen)
	
					if entitylib.isAlive then
						for _, v in bedwars.StatusEffectUtil:getAllActive(lplr.Character) do
							if (v.expireTime or 0) - workspace:GetServerTimeNow() > 0 and (negative[v.statusEffect] and ShowNegative.Enabled or not negative[v.statusEffect] and ShowPositive.Enabled) then
								seen[v.statusEffect] = true
	
								if effects[v.statusEffect] ~= v.expireTime then
									task.spawn(Added, v)
								end
							end
						end
					end
	
					for i in effects do
						if not seen[i] then
							effects[i] = nil
						end
					end
	
					task.wait(0.1)
				until not PotionStatus.Enabled
	
				table.clear(effects)
			end
		end,
		Size = UDim2.fromOffset(240, 64),
		Tooltip = 'Shows your currently active effects'
	})
	
	background = PotionStatus.Children
	background.BackgroundColor3 = Color3.new()
	background.BackgroundTransparency = 0.5
	local backgroundcorner = Instance.new('UICorner')
	backgroundcorner.CornerRadius = UDim.new(0, 4)
	backgroundcorner.Parent = background
	local layout = Instance.new('UIListLayout')
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = background
	vape:Clean(layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
	
		background.Size = UDim2.fromOffset(layout.AbsoluteContentSize.X, layout.AbsoluteContentSize.Y)
	end))
	ShowPositive = PotionStatus:CreateToggle({
		Name = 'Show Positive Effects',
		Default = true
	})
	ShowNegative = PotionStatus:CreateToggle({
		Name = 'Show Negative Effects',
		Default = true
	})
	Background = PotionStatus:CreateToggle({
		Name = 'Render background',
		Function = function(callback)
			if BackgroundColor then
				background.BackgroundTransparency = callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = callback
			end
		end,
		Default = true
	})
	BackgroundColor = PotionStatus:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			background.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			background.BackgroundTransparency = Background.Enabled and 1 - opacity or 1
		end,
		Darker = true
	})
end)

run(function()
	local ReachDisplay
	local label
	
	ReachDisplay = vape.Legit:CreateModule({
		Name = 'Reach Display',
		Category = 'HUD',
		Icon = getvapeasset('catsix/assets/new/legit_reachdisplay.png'),
		Function = function(callback)
			if callback then
				repeat
					label.Text = (store.attackReachUpdate > tick() and store.attackReach or '0.00')..' studs'
					task.wait(0.4)
				until not ReachDisplay.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41)
	})
	
	ReachDisplay:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	ReachDisplay:CreateColorSlider({
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
	label.Text = '0.00 studs'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = ReachDisplay.Children
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
	local beattick = tick()
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
		table.insert(alreadypicked, chosensong)
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = tick() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_songbeats.png'),
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				repeat
					if not songobj.Playing then choosesong() end
					if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
						beattick = tick() + songbpm
						oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
						songtween:Play()
					end
					task.wait()
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
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
	local SoundChanger
	local List
	local soundlist = {}
	local old
	
	SoundChanger = vape.Legit:CreateModule({
		Name = 'SoundChanger',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_soundchanger.png'),
		Function = function(callback)
			if callback then
				old = bedwars.AudioManager.playAudio
				bedwars.AudioManager.playAudio = function(self, id, ...)
					if soundlist[id] then
						id = soundlist[id]
					end
	
					return old(self, id, ...)
				end
			else
				bedwars.AudioManager.playAudio = old
			end
		end,
		Tooltip = 'Change ingame sounds to custom ones.'
	})
	
	List = SoundChanger:CreateTextList({
		Name = 'Sounds',
		Placeholder = '(DAMAGE_1/ben.mp3)',
		Function = function()
			table.clear(soundlist)
			for _, v in List.ListEnabled do
				local split = v:split('/')
				local id = bedwars.SoundList[split[1]]
				if id and #split > 1 then
					soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
				end
			end
		end
	})
end)

run(function()
	local UICleanup
	local OpenInv
	local KillFeed
	local OldTabList
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local old, new = {}, {}
	local oldkillfeed
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) and val ~= nil then return end
	
		new[func][ind] = val
		if UICleanup.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	UICleanup = vape.Legit:CreateModule({
		Name = 'UI Cleanup',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_uicleanup.png'),
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				if OpenInv.Enabled then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				end
	
				if KillFeed.Enabled then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
				end
			else
				if oldinvrender then
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
	
				if KillFeed.Enabled then
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end
			end
		end,
		Tooltip = 'Cleans up the UI for kits & main'
	})
	
	UICleanup:CreateToggle({
		Name = 'Resize Health',
		Function = function(callback)
			modifyconstant(HotbarApp, 60, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 15).render, 30, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 23).tweenPosition, 16, callback and 0 or nil)
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'No Hotbar Numbers',
		Function = function(callback)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 90, callback and 0 or nil)
			modifyconstant(func, 71, callback and 0 or nil)
		end,
		Default = true
	})
	OpenInv = UICleanup:CreateToggle({
		Name = 'No Inventory Button',
		Function = function(callback)
			modifyconstant(HotbarApp, 78, callback and 0 or nil)
			if UICleanup.Enabled then
				if callback then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				else
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
			end
		end,
		Default = true
	})
	KillFeed = UICleanup:CreateToggle({
		Name = 'No Kill Feed',
		Function = function(callback)
			if UICleanup.Enabled then
				if callback then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				else
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
			end
		end,
		Default = true
	})
	OldTabList = UICleanup:CreateToggle({
		Name = 'Old Player List',
		Function = function(callback)
			if UICleanup.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
			end
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'Fix Queue Card',
		Function = function(callback)
			modifyconstant(bedwars.QueueCard.render, 15, callback and 0.1 or nil)
		end,
		Default = true
	})
end)

run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local Size
	local NoBob
	local Visuals
	local FillColor
	local OutlineColor
	local Rots = {}
	local Highlights = {}
	local old, oldc1
	local rootjoint, rootc0, rootoffset
	local rig
	
	local function highlightAccessory(accessory)
		local handle = accessory:FindFirstChild('Handle')
		if handle then
			local highlight = Instance.new('Highlight')
			highlight.Name = 'ViewmodelVisuals'
			highlight.FillColor = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
			highlight.FillTransparency = FillColor.Opacity
			highlight.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
			highlight.OutlineTransparency = OutlineColor.Opacity
			highlight.Parent = handle
			Viewmodel:Clean(highlight)
			table.insert(Highlights, highlight)
		end
	end
	
	local function startViewmodel()
		local viewmodel
		repeat
			viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if viewmodel or not Viewmodel.Enabled then break end
			task.wait(0.1)
		until false
		if not viewmodel or not Viewmodel.Enabled or rig == viewmodel then return end
	
		rig = viewmodel
		viewmodel:ScaleTo(1)
		oldc1 = viewmodel.RightHand.RightWrist.C1
		viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
		local lowertorso = viewmodel:FindFirstChild('LowerTorso')
		local accessory = viewmodel:FindFirstChildWhichIsA('Accessory')
		local reference = accessory and accessory:FindFirstChild('Handle') or viewmodel:FindFirstChild('RightHand')
		rootjoint = lowertorso and lowertorso:FindFirstChildWhichIsA('Motor6D')
		rootc0 = rootjoint and rootjoint.C0
		rootoffset = reference and viewmodel.HumanoidRootPart.CFrame:PointToObjectSpace(reference.Position)
		viewmodel:ScaleTo(Size.Value)
		if rootjoint and rootc0 and rootoffset then
			rootjoint.C0 = (rootc0 - rootc0.Position) + (rootc0.Position * Size.Value) + (rootoffset * (1 - Size.Value))
		end
	
		Viewmodel:Clean(viewmodel.ChildAdded:Connect(function(v)
			if v:IsA('Accessory') and Size.Value ~= 1 then
				if store.matchState == 0 then
					repeat task.wait() until store.matchState ~= 0
					task.wait(0.5)
				end
				bedwars.scaleTool(v, Size.Value)
			end
		end))
		bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
	end
	
	local function startVisuals()
		local viewmodel
		repeat
			viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if viewmodel or not Viewmodel.Enabled then break end
			task.wait(0.1)
		until false
		if not viewmodel or not Viewmodel.Enabled then return end
	
		for _, v in viewmodel:GetChildren() do
			if v:IsA('Accessory') then
				highlightAccessory(v)
			end
		end
	
		Viewmodel:Clean(viewmodel.ChildAdded:Connect(function(v)
			for i = #Highlights, 1, -1 do
				if not Highlights[i].Parent then
					table.remove(Highlights, i)
				end
			end
			if v:IsA('Accessory') then
				highlightAccessory(v)
			end
		end))
	end
	
	Viewmodel = vape.Legit:CreateModule({
		Name = 'Viewmodel',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_viewmodel.png'),
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if callback then
				old = bedwars.ViewmodelController.playAnimation
				if NoBob.Enabled then
					bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
						if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
						return old(self, animtype, ...)
					end
				end
	
				Viewmodel:Clean(gameCamera.ChildAdded:Connect(function(v)
					if v.Name == 'Viewmodel' then
						startViewmodel()
	
						if Visuals.Enabled then
							startVisuals()
						end
					end
				end))
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
	
				startViewmodel()
	
				if Visuals.Enabled then
					startVisuals()
				end
			else
				bedwars.ViewmodelController.playAnimation = old
				if viewmodel and oldc1 then
					viewmodel:ScaleTo(1)
					viewmodel.RightHand.RightWrist.C1 = oldc1
	
					if rootjoint and rootc0 then
						rootjoint.C0 = rootc0
					end
				end
	
				oldc1 = nil
				rig = nil
				rootjoint = nil
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
				table.clear(Highlights)
			end
		end,
		Tooltip = 'Changes the viewmodel animations and visuals'
	})
	
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
			end
		end,
		Default = 0.8
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
			end
		end,
		Default = 0.8
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -0.2,
		Max = 2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
			end
		end,
		Default = -0.2
	})
	Size = Viewmodel:CreateSlider({
		Name = 'Size',
		Min = 0.1,
		Max = 2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled and gameCamera:FindFirstChild('Viewmodel') then
				gameCamera.Viewmodel:ScaleTo(val)
				if rootjoint and rootc0 and rootoffset then
					rootjoint.C0 = (rootc0 - rootc0.Position) + (rootc0.Position * val) + (rootoffset * (1 - val))
				end
			end
		end,
		Default = 1
	})
	for _, v in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, Viewmodel:CreateSlider({
			Name = v,
			Min = 0,
			Max = 360,
			Function = function(val)
				if Viewmodel.Enabled then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = (oldc1 + oldc1.Position * (Size.Value - 1)) * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
			end
		}))
	end
	NoBob = Viewmodel:CreateToggle({
		Name = 'No Bobbing',
		Function = function()
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end,
		Default = true
	})
	Visuals = Viewmodel:CreateToggle({
		Name = 'Visuals',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end,
		Tooltip = 'Highlights the item held in your viewmodel'
	})
	FillColor = Viewmodel:CreateColorSlider({
		Name = 'Fill Color',
		DefaultSat = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			for _, v in Highlights do
				v.FillColor = Color3.fromHSV(hue, sat, val)
				v.FillTransparency = opacity
			end
		end
	})
	OutlineColor = Viewmodel:CreateColorSlider({
		Name = 'Outline Color',
		DefaultValue = 0,
		DefaultOpacity = 0,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			for _, v in Highlights do
				v.OutlineColor = Color3.fromHSV(hue, sat, val)
				v.OutlineTransparency = opacity
			end
		end
	})
end)

run(function()
	local WinEffect
	local List
	local NameToId = {}
	
	WinEffect = vape.Legit:CreateModule({
		Name = 'WinEffect',
		Category = 'Game',
		Icon = getvapeasset('catsix/assets/new/legit_wineffect.png'),
		Function = function(callback)
			if callback then
				WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					for _, v in getconnections(bedwars.Handler:Get('WinEffectTriggered').Remote.instance.OnClientEvent) do
						if v.Function then
							v.Function({
								winEffectType = NameToId[List.Value],
								winningPlayer = lplr
							})
						end
					end
				end))
			end
		end,
		Tooltip = 'Allows you to select any clientside win effect'
	})
	
	local WinEffectName = {}
	for i, v in bedwars.WinEffectMeta do
		table.insert(WinEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(WinEffectName)
	List = WinEffect:CreateDropdown({
		Name = 'Effects',
		List = WinEffectName
	})
end)

run(function()
	local EnemyBreakVisuals = {Enabled = false}
	local Mode = {Value = 'All Effects'}
	local ColorMode = {Value = 'Rainbow'}
	local CustomColor = {Hue = 0.95, Sat = 0.85, Value = 1}
	local MaxDistance = {Value = 15}
	local PulseEffect = {Enabled = true}
	local ShowTracers = {Enabled = true}
	local ShowBreakerInfo = {Enabled = true}
	local ParticleBurst = {Enabled = true}
	local LingerTime = {Value = 2.0}
	local GlowSpeed = {Value = 2}

	local activeTargets = {}
	local renderedVisuals = {}
	local previousHealthCache = {}
	local visualsFolder = Instance.new('Folder')
	visualsFolder.Name = 'KingVape_EnemyBreakVisuals'
	visualsFolder.Parent = workspace

	local oldPlayHit, oldPlayBreak, oldUpdateHealthbar

	local function isEnemy(plr)
		if not plr or plr == lplr then return false end
		if isFriend and isFriend(plr) then return false end

		local localTeam = lplr:GetAttribute('Team') or (lplr.Team and lplr.Team.Name)
		local enemyTeam = plr:GetAttribute('Team') or (plr.Team and plr.Team.Name)
		if localTeam and enemyTeam and localTeam == enemyTeam then
			return false
		end

		return true
	end

	local function findNearestEnemy(worldPos)
		if not worldPos then return nil end
		local nearest, nearestDist = nil, 22
		for _, plr in playersService:GetPlayers() do
			if isEnemy(plr) and plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') then
				local d = (plr.Character.HumanoidRootPart.Position - worldPos).Magnitude
				if d < nearestDist then
					nearest = plr
					nearestDist = d
				end
			end
		end
		return nearest
	end

	local function getPartAtPosition(worldPos)
		if not worldPos then return nil end
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(worldPos), Vector3.new(3.2, 3.2, 3.2)) do
			if part:IsA('BasePart') and part.Anchored and part.Parent ~= visualsFolder and not part:IsA('Terrain') then
				return part
			end
		end
		return nil
	end

	local function resolveBlock(blockPos, targetBlock)
		local blockPart = nil
		local worldPos = nil
		local gridPos = nil

		if targetBlock and targetBlock:IsA('BasePart') and targetBlock.Parent then
			blockPart = targetBlock
			worldPos = targetBlock.Position
			if bedwars.BlockController and bedwars.BlockController.getBlockPosition then
				pcall(function()
					gridPos = bedwars.BlockController:getBlockPosition(targetBlock.Position)
				end)
			end
		elseif typeof(blockPos) == 'Vector3' then
			if bedwars.BlockController then
				if math.abs(blockPos.X) < 1500 and math.abs(blockPos.Y) < 500 and math.abs(blockPos.Z) < 1500 then
					gridPos = Vector3.new(math.floor(blockPos.X + 0.5), math.floor(blockPos.Y + 0.5), math.floor(blockPos.Z + 0.5))
					if bedwars.BlockController.getWorldPosition then
						pcall(function()
							worldPos = bedwars.BlockController:getWorldPosition(gridPos)
						end)
					end
					worldPos = worldPos or (gridPos * 3)
				else
					worldPos = blockPos
					pcall(function()
						gridPos = bedwars.BlockController:getBlockPosition(worldPos)
					end)
				end

				if gridPos and bedwars.BlockController.getStore and bedwars.BlockController:getStore().getBlockAt then
					pcall(function()
						blockPart = bedwars.BlockController:getStore():getBlockAt(gridPos)
					end)
				end
			else
				gridPos = blockPos
				worldPos = gridPos * 3
			end

			if not blockPart and worldPos then
				blockPart = getPartAtPosition(worldPos)
			end
			if blockPart and not worldPos then
				worldPos = blockPart.Position
			end
		end

		return blockPart, worldPos, gridPos
	end

	local function getBlockHealthInfo(blockPart, gridPos)
		local curHealth, maxHealth = nil, nil
		if blockPart then
			curHealth = blockPart:GetAttribute('Health') or blockPart:GetAttribute('1')
			maxHealth = blockPart:GetAttribute('MaxHealth') or 100
		end
		if gridPos and bedwars.BlockController and bedwars.BlockController.getStore then
			pcall(function()
				local blockdata = bedwars.BlockController:getStore():getBlockData(gridPos)
				if blockdata then
					curHealth = curHealth or blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')
					maxHealth = maxHealth or blockdata:GetAttribute('MaxHealth')
				end
			end)
		end
		return curHealth, maxHealth or 100
	end

	local function cleanupVisual(key)
		if renderedVisuals[key] then
			pcall(function()
				if renderedVisuals[key].ProxyPart then renderedVisuals[key].ProxyPart:Destroy() end
				if renderedVisuals[key].Highlight then renderedVisuals[key].Highlight:Destroy() end
				if renderedVisuals[key].SelectionBox then renderedVisuals[key].SelectionBox:Destroy() end
				if renderedVisuals[key].BoxAdornment then renderedVisuals[key].BoxAdornment:Destroy() end
				if renderedVisuals[key].TracerPart then renderedVisuals[key].TracerPart:Destroy() end
				if renderedVisuals[key].Billboard then renderedVisuals[key].Billboard:Destroy() end
			end)
			renderedVisuals[key] = nil
		end
	end

	local function cleanupAllVisuals()
		for key in renderedVisuals do
			cleanupVisual(key)
		end
		table.clear(renderedVisuals)
		table.clear(activeTargets)
		table.clear(previousHealthCache)
	end

	local function spawnBreakParticle(cf, col)
		if not ParticleBurst.Enabled then return end
		pcall(function()
			local ring = Instance.new('Part')
			ring.Size = Vector3.new(0.5, 0.1, 0.5)
			ring.CFrame = cf
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.Material = Enum.Material.Neon
			ring.Color = col
			ring.Parent = visualsFolder

			local mesh = Instance.new('SpecialMesh')
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = 'rbxassetid://3270017'
			mesh.Scale = Vector3.new(1, 1, 1)
			mesh.Parent = ring

			tweenService:Create(mesh, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = Vector3.new(8, 2, 8)
			}):Play()
			tweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1
			}):Play()

			task.delay(0.5, function()
				pcall(function() ring:Destroy() end)
			end)
		end)
	end

	local function getColor(distBlocks, healthPct)
		if ColorMode.Value == 'Custom' then
			return Color3.fromHSV(CustomColor.Hue, CustomColor.Sat, CustomColor.Value)
		elseif ColorMode.Value == 'Rainbow' then
			local hue = (os.clock() * GlowSpeed.Value * 0.3) % 1
			return Color3.fromHSV(hue, 0.85, 1)
		elseif ColorMode.Value == 'Distance Gradient' then
			local ratio = math.clamp((distBlocks or 15) / math.max(MaxDistance.Value, 1), 0, 1)
			return Color3.fromHSV(ratio * 0.33, 0.9, 1)
		elseif ColorMode.Value == 'Pulse Glow' then
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * GlowSpeed.Value * 4)
			return Color3.fromHSV(CustomColor.Hue, 0.7 + 0.3 * pulse, 0.6 + 0.4 * pulse)
		end
		return Color3.fromRGB(255, 65, 65)
	end

	local function handleBlockEvent(blockName, blockPos, player, actionType, curHealth, maxHealth, dmg, targetBlock)
		if not EnemyBreakVisuals.Enabled then return end

		local blockPart, worldPos, gridPos = resolveBlock(blockPos, targetBlock)
		if not worldPos then return end

		local breaker = player
		if not breaker or not breaker:IsA('Player') then
			breaker = findNearestEnemy(worldPos)
		end

		if not breaker or not isEnemy(breaker) then
			return
		end

		local myRoot = lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')
		local myPos = myRoot and myRoot.Position or (gameCamera and gameCamera.CFrame.Position)
		if not myPos then return end

		local distToMe = (worldPos - myPos).Magnitude
		local distBlocks = math.floor(distToMe / 3)
		if distBlocks > MaxDistance.Value then
			return
		end

		local key = blockPart or (gridPos and string.format('%d_%d_%d', gridPos.X, gridPos.Y, gridPos.Z)) or string.format('%d_%d_%d', math.floor(worldPos.X), math.floor(worldPos.Y), math.floor(worldPos.Z))

		local detectedHealth, detectedMax = getBlockHealthInfo(blockPart, gridPos)
		local finalCurHealth = curHealth or detectedHealth
		local finalMaxHealth = maxHealth or detectedMax or 100

		local existing = activeTargets[key]
		local hitCount = (existing and existing.hits or 0) + 1
		local currentAction = actionType or 'damage'

		activeTargets[key] = {
			key = key,
			blockName = blockName or (blockPart and blockPart.Name) or 'block',
			worldPos = worldPos,
			gridPos = gridPos,
			targetPart = blockPart,
			enemy = breaker,
			lastHit = tick(),
			hits = hitCount,
			action = currentAction,
			curHealth = finalCurHealth,
			maxHealth = finalMaxHealth,
			dmg = dmg
		}

		local col = getColor(distBlocks, finalCurHealth and finalMaxHealth and (finalCurHealth / finalMaxHealth))
		spawnBreakParticle(CFrame.new(worldPos), col)
	end

	local function scanDamagedBlocksNearEnemies()
		local myRoot = lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')
		local myPos = myRoot and myRoot.Position or (gameCamera and gameCamera.CFrame.Position)
		if not myPos then return end

		for _, plr in playersService:GetPlayers() do
			if isEnemy(plr) and plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') then
				local enemyPos = plr.Character.HumanoidRootPart.Position
				local distToMe = (enemyPos - myPos).Magnitude
				if distToMe <= (MaxDistance.Value * 3 + 15) then
					if store and store.blocks then
						for _, block in store.blocks do
							if block and block.Parent and block:IsA('BasePart') then
								local distToEnemy = (block.Position - enemyPos).Magnitude
								if distToEnemy <= 18 then
									local curHealth = block:GetAttribute('Health') or block:GetAttribute('1')
									local maxHealth = block:GetAttribute('MaxHealth') or 100
									if curHealth and maxHealth and curHealth < maxHealth then
										local prev = previousHealthCache[block]
										if prev == nil or curHealth < prev then
											previousHealthCache[block] = curHealth
											handleBlockEvent(block.Name, block.Position, plr, 'damage', curHealth, maxHealth, (prev and (prev - curHealth) or nil), block)
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local function renderActiveTargets()
		local now = tick()
		local myRoot = lplr.Character and lplr.Character:FindFirstChild('HumanoidRootPart')
		local myPos = myRoot and myRoot.Position or (gameCamera and gameCamera.CFrame.Position)
		if not myPos then return end

		local pulseAlpha = PulseEffect.Enabled and (0.5 + 0.5 * math.sin(now * GlowSpeed.Value * 5)) or 1

		for key, data in activeTargets do
			local timeSinceHit = now - data.lastHit
			local enemy = data.enemy
			local enemyRoot = enemy and enemy.Character and enemy.Character:FindFirstChild('HumanoidRootPart')

			if timeSinceHit > LingerTime.Value or not enemy or not enemy.Parent then
				cleanupVisual(key)
				activeTargets[key] = nil
			else
				local worldPos = data.worldPos
				local targetPart = data.targetPart
				if (not targetPart or not targetPart.Parent) and data.gridPos and bedwars.BlockController and bedwars.BlockController.getStore then
					pcall(function()
						targetPart = bedwars.BlockController:getStore():getBlockAt(data.gridPos)
					end)
					data.targetPart = targetPart
				end
				if not targetPart or not targetPart.Parent then
					targetPart = getPartAtPosition(worldPos)
					data.targetPart = targetPart
				end

				local distToMe = (worldPos - myPos).Magnitude
				local distBlocks = math.floor(distToMe / 3)

				if distBlocks > (MaxDistance.Value + 2) then
					cleanupVisual(key)
					activeTargets[key] = nil
				else
					local hpPct = nil
					if data.curHealth and data.maxHealth and data.maxHealth > 0 then
						hpPct = math.clamp(data.curHealth / data.maxHealth, 0, 1)
					end

					local col = getColor(distBlocks, hpPct)
					local vis = renderedVisuals[key]
					if not vis then
						vis = {}
						renderedVisuals[key] = vis
					end

					local fadeProgress = math.clamp(1 - (timeSinceHit / LingerTime.Value), 0, 1)
					local currentAlpha = fadeProgress * (0.65 + 0.35 * pulseAlpha)

					if not targetPart then
						if not vis.ProxyPart or not vis.ProxyPart.Parent then
							if vis.ProxyPart then vis.ProxyPart:Destroy() end
							local p = Instance.new('Part')
							p.Size = Vector3.new(3, 3, 3)
							p.CFrame = CFrame.new(worldPos)
							p.Anchored = true
							p.CanCollide = false
							p.CanQuery = false
							p.Transparency = 1
							p.Parent = visualsFolder
							vis.ProxyPart = p
						end
						targetPart = vis.ProxyPart
					end

					if Mode.Value == 'Highlight Glow' or Mode.Value == 'All Effects' then
						if not vis.Highlight or vis.Highlight.Adornee ~= targetPart then
							if vis.Highlight then vis.Highlight:Destroy() end
							local hl = Instance.new('Highlight')
							hl.Adornee = targetPart
							hl.OutlineTransparency = 0
							hl.Parent = visualsFolder
							vis.Highlight = hl
						end
						vis.Highlight.FillColor = col
						vis.Highlight.OutlineColor = col
						vis.Highlight.FillTransparency = math.clamp(1 - (currentAlpha * 0.7), 0.2, 1)
						vis.Highlight.OutlineTransparency = math.clamp(1 - currentAlpha, 0, 1)
					elseif vis.Highlight then
						vis.Highlight:Destroy()
						vis.Highlight = nil
					end

					if Mode.Value == 'Selection Box' or Mode.Value == 'All Effects' then
						if not vis.SelectionBox or vis.SelectionBox.Adornee ~= targetPart then
							if vis.SelectionBox then vis.SelectionBox:Destroy() end
							local sbox = Instance.new('SelectionBox')
							sbox.Adornee = targetPart
							sbox.LineThickness = 0.06
							sbox.Parent = visualsFolder
							vis.SelectionBox = sbox
						end
						vis.SelectionBox.Color3 = col
						vis.SelectionBox.SurfaceColor3 = col
						vis.SelectionBox.SurfaceTransparency = math.clamp(1 - (currentAlpha * 0.4), 0.5, 1)
						vis.SelectionBox.Transparency = math.clamp(1 - currentAlpha, 0, 1)
					elseif vis.SelectionBox then
						vis.SelectionBox:Destroy()
						vis.SelectionBox = nil
					end

					if Mode.Value == 'Neon Box' or Mode.Value == 'All Effects' then
						if not vis.BoxAdornment or vis.BoxAdornment.Adornee ~= targetPart then
							if vis.BoxAdornment then vis.BoxAdornment:Destroy() end
							local box = Instance.new('BoxHandleAdornment')
							box.Size = (targetPart.Size or Vector3.new(3, 3, 3)) + Vector3.new(0.06, 0.06, 0.06)
							box.AlwaysOnTop = true
							box.ZIndex = 3
							box.Adornee = targetPart
							box.Parent = visualsFolder
							vis.BoxAdornment = box
						end
						vis.BoxAdornment.Color3 = col
						vis.BoxAdornment.Transparency = math.clamp(1 - (currentAlpha * 0.6), 0.3, 1)
					elseif vis.BoxAdornment then
						vis.BoxAdornment:Destroy()
						vis.BoxAdornment = nil
					end

					if ShowTracers.Enabled and enemyRoot then
						local originPos = enemyRoot.Position
						local targetCenter = worldPos
						local tracerDist = (targetCenter - originPos).Magnitude
						local tracerCFrame = CFrame.lookAt(originPos:Lerp(targetCenter, 0.5), targetCenter)

						if not vis.TracerPart or not vis.TracerPart.Parent then
							if vis.TracerPart then vis.TracerPart:Destroy() end
							local tr = Instance.new('Part')
							tr.Anchored = true
							tr.CanCollide = false
							tr.CanQuery = false
							tr.Material = Enum.Material.Neon
							tr.Parent = visualsFolder
							vis.TracerPart = tr
						end
						vis.TracerPart.Size = Vector3.new(0.12, 0.12, tracerDist)
						vis.TracerPart.CFrame = tracerCFrame
						vis.TracerPart.Color = col
						vis.TracerPart.Transparency = math.clamp(1 - (currentAlpha * 0.75), 0.25, 1)
					elseif vis.TracerPart then
						vis.TracerPart:Destroy()
						vis.TracerPart = nil
					end

					if ShowBreakerInfo.Enabled then
						local enemyHumanoid = enemy.Character and enemy.Character:FindFirstChildOfClass('Humanoid')
						local enemyHealth = enemyHumanoid and math.floor(enemyHumanoid.Health) or 100
						
						local statusText
						if data.action == 'break' then
							statusText = '<font color="#FF3333">BROKEN</font>'
						elseif data.curHealth and data.maxHealth then
							statusText = string.format('<font color="#FFAA00">%d/%d HP</font>', math.floor(data.curHealth), math.floor(data.maxHealth))
						else
							statusText = string.format('Hit #%d', data.hits)
						end

						local infoText = string.format('<b>⛏️ %s</b> [%d HP] • %s • %d blk', enemy.DisplayName or enemy.Name, enemyHealth, statusText, distBlocks)

						if not vis.Billboard or vis.Billboard.Adornee ~= targetPart then
							if vis.Billboard then vis.Billboard:Destroy() end
							local bb = Instance.new('BillboardGui')
							bb.Size = UDim2.fromOffset(180, 26)
							bb.StudsOffset = Vector3.new(0, (targetPart.Size.Y or 3) / 2 + 1.2, 0)
							bb.AlwaysOnTop = true
							bb.Adornee = targetPart
							bb.Parent = visualsFolder

							local frame = Instance.new('Frame')
							frame.Size = UDim2.fromScale(1, 1)
							frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
							frame.BackgroundTransparency = 0.2
							frame.BorderSizePixel = 0
							frame.Parent = bb

							local corner = Instance.new('UICorner')
							corner.CornerRadius = UDim.new(0, 6)
							corner.Parent = frame

							local stroke = Instance.new('UIStroke')
							stroke.Thickness = 1.2
							stroke.Color = col
							stroke.Parent = frame

							local label = Instance.new('TextLabel')
							label.Size = UDim2.fromScale(1, 1)
							label.BackgroundTransparency = 1
							label.Font = Enum.Font.GothamBold
							label.TextSize = 11
							label.TextColor3 = Color3.new(1, 1, 1)
							label.RichText = true
							label.Text = infoText
							label.Parent = frame

							vis.Billboard = bb
							vis.InfoLabel = label
							vis.InfoStroke = stroke
						else
							if vis.InfoLabel then vis.InfoLabel.Text = infoText end
							if vis.InfoStroke then vis.InfoStroke.Color = col end
						end
					elseif vis.Billboard then
						vis.Billboard:Destroy()
						vis.Billboard = nil
					end
				end
			end
		end
	end

	local category = (vape.Categories and (vape.Categories.Render or vape.Categories.World or vape.Categories.Minigames)) or vape.Render
	if not category then return end

	EnemyBreakVisuals = category:CreateModule({
		Name = 'EnemyBreakVisuals',
		Tooltip = 'Accurately highlights blocks that enemies damage or break via server events with custom effects.',
		Function = function(callback)
			if not callback then
				cleanupAllVisuals()
				if oldPlayHit and bedwars.BlockBreaker and bedwars.BlockBreaker.breakEffect then
					bedwars.BlockBreaker.breakEffect.playHit = oldPlayHit
					oldPlayHit = nil
				end
				if oldPlayBreak and bedwars.BlockBreaker and bedwars.BlockBreaker.breakEffect then
					bedwars.BlockBreaker.breakEffect.playBreak = oldPlayBreak
					oldPlayBreak = nil
				end
				if oldUpdateHealthbar and bedwars.BlockBreaker then
					bedwars.BlockBreaker.updateHealthbar = oldUpdateHealthbar
					oldUpdateHealthbar = nil
				end
			else
				EnemyBreakVisuals:Clean(runService.RenderStepped:Connect(function()
					scanDamagedBlocksNearEnemies()
					renderActiveTargets()
				end))

				if bedwars.BlockBreaker and bedwars.BlockBreaker.breakEffect then
					oldPlayHit = bedwars.BlockBreaker.breakEffect.playHit
					bedwars.BlockBreaker.breakEffect.playHit = function(self, blockName, blockPos, player, ...)
						pcall(function()
							handleBlockEvent(blockName, blockPos, player, 'hit')
						end)
						return oldPlayHit(self, blockName, blockPos, player, ...)
					end

					oldPlayBreak = bedwars.BlockBreaker.breakEffect.playBreak
					bedwars.BlockBreaker.breakEffect.playBreak = function(self, blockName, blockPos, player, ...)
						pcall(function()
							handleBlockEvent(blockName, blockPos, player, 'break')
						end)
						return oldPlayBreak(self, blockName, blockPos, player, ...)
					end
				end

				if bedwars.BlockBreaker and bedwars.BlockBreaker.updateHealthbar then
					oldUpdateHealthbar = bedwars.BlockBreaker.updateHealthbar
					bedwars.BlockBreaker.updateHealthbar = function(self, blockRef, curHealth, maxHealth, dmg, blockPart, ...)
						pcall(function()
							local blockPos = blockRef and blockRef.blockPosition
							handleBlockEvent(blockPart and blockPart.Name, blockPos, nil, 'damage', curHealth, maxHealth, dmg, blockPart)
						end)
						return oldUpdateHealthbar(self, blockRef, curHealth, maxHealth, dmg, blockPart, ...)
					end
				end

				if vapeEvents and vapeEvents.BreakBlockEvent then
					EnemyBreakVisuals:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(data)
						local plr = data.player or (data.blockRef and data.blockRef.player)
						local blockPos = data.blockRef and data.blockRef.blockPosition
						if blockPos then
							handleBlockEvent('block', blockPos, plr, 'break')
						end
					end))
				end
			end
		end
	})

	Mode = EnemyBreakVisuals:CreateDropdown({
		Name = 'Visual Mode',
		List = {'All Effects', 'Highlight Glow', 'Selection Box', 'Neon Box'},
		Default = 'All Effects'
	})
	ColorMode = EnemyBreakVisuals:CreateDropdown({
		Name = 'Color Mode',
		List = {'Rainbow', 'Custom', 'Distance Gradient', 'Pulse Glow'},
		Default = 'Rainbow',
		Function = function(val)
			if CustomColor and CustomColor.Object then
				CustomColor.Object.Visible = (val == 'Custom' or val == 'Pulse Glow')
			end
		end
	})
	CustomColor = EnemyBreakVisuals:CreateColorSlider({
		Name = 'Custom Color',
		Function = function(h, s, v)
			CustomColor.Hue = h
			CustomColor.Sat = s
			CustomColor.Value = v
		end,
		Darker = true,
		Visible = false
	})
	MaxDistance = EnemyBreakVisuals:CreateSlider({
		Name = 'Max Distance',
		Min = 5,
		Max = 60,
		Default = 15,
		Suffix = 'blocks',
		Tooltip = 'Only highlights blocks damaged/broken within this distance (in blocks)'
	})
	PulseEffect = EnemyBreakVisuals:CreateToggle({
		Name = 'Pulse Animation',
		Default = true,
		Tooltip = 'Smooth breathing/pulsing animation for glow and highlights'
	})
	ShowTracers = EnemyBreakVisuals:CreateToggle({
		Name = 'Tracers',
		Default = true,
		Tooltip = 'Draws 3D tracer line connecting the enemy breaker to the block'
	})
	ShowBreakerInfo = EnemyBreakVisuals:CreateToggle({
		Name = 'Show Breaker Info',
		Default = true,
		Tooltip = 'Displays enemy name, health, hit count/action, and distance above block'
	})
	ParticleBurst = EnemyBreakVisuals:CreateToggle({
		Name = 'Particle Shockwave',
		Default = true,
		Tooltip = 'Spawns expanding neon shockwave ring when block is damaged or broken'
	})
	LingerTime = EnemyBreakVisuals:CreateSlider({
		Name = 'Linger Duration',
		Min = 0.5,
		Max = 5,
		Decimal = 10,
		Default = 2.0,
		Suffix = 's',
		Tooltip = 'How long the highlight remains visible after the block was damaged'
	})
	GlowSpeed = EnemyBreakVisuals:CreateSlider({
		Name = 'Shift Speed',
		Min = 0.5,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Tooltip = 'Speed of color shifting and pulsing animations'
	})
end)
