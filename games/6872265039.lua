local buildclock = os.clock()
local run = function(func)
	xpcall(func, function(err)
		warn(`[KingVape] {err}\n{debug.traceback(nil, 2)}`)
		if shared.vape then
			shared.vape:CreateNotification('Vape', `A module failed to load : {err}`, 15, 'alert')
		end
	end)

	if os.clock() - buildclock > 0.004 then
		task.wait()
		buildclock = os.clock()
	end
end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end

	local KnitInit, Knit
	local knitAttempts = 0
	repeat
		knitAttempts = knitAttempts + 1
		KnitInit, Knit = pcall(function()
			if debug.getupvalue then
				local suc, res = pcall(function()
					return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
				end)
				if suc and res then return res end
			end
			return require(replicatedStorage['rbxts_include']['node_modules']['@easy-games'].knit.src).KnitClient
		end)
		if KnitInit and Knit then break end
		task.wait(0.05)
	until (KnitInit and Knit) or knitAttempts > 30

	if not Knit then
		pcall(function()
			Knit = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games'].knit.src).KnitClient
		end)
	end

	if Knit and debug.getupvalue then
		pcall(function()
			if not debug.getupvalue(Knit.Start, 1) then
				local startWait = tick()
				repeat task.wait(0.05) until debug.getupvalue(Knit.Start, 1) or (tick() - startWait > 2)
			end
		end)
	end

	local function safeRequire(path)
		local suc, res = pcall(function() return require(path) end)
		return suc and res or nil
	end

	local Flamework
	pcall(function()
		Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	end)
	local Client
	pcall(function()
		Client = require(replicatedStorage.TS.remotes).default.Client
	end)

	local crateMeta = nil
	if Flamework and debug.getupvalue then
		pcall(function()
			local controller = Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController')
			if controller and controller.onStart then
				crateMeta = debug.getupvalue(controller.onStart, 3)
			end
		end)
	end

	bedwars = setmetatable({
		Client = Client or {},
		CrateItemMeta = crateMeta,
		EmoteDisplayMeta = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('locker') and replicatedStorage.TS.locker:FindFirstChild('emote') and replicatedStorage.TS.locker.emote:FindFirstChild('emote-display-meta')) and safeRequire(replicatedStorage.TS.locker.emote['emote-display-meta']).EmoteDisplayMeta,
		EmoteMeta = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('locker') and replicatedStorage.TS.locker:FindFirstChild('emote') and replicatedStorage.TS.locker.emote:FindFirstChild('emote-meta')) and safeRequire(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta,
		EmoteType = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('locker') and replicatedStorage.TS.locker:FindFirstChild('emote') and replicatedStorage.TS.locker.emote:FindFirstChild('emote-type')) and safeRequire(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('animation') and replicatedStorage.TS.animation:FindFirstChild('animation-util')) and safeRequire(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		GamePlayerUtil = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('player') and replicatedStorage.TS.player:FindFirstChild('player-util')) and safeRequire(replicatedStorage.TS.player['player-util']).GamePlayerUtil,
		MilestoneRewards = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('milestones') and replicatedStorage.TS.milestones:FindFirstChild('milestones')) and safeRequire(replicatedStorage.TS.milestones.milestones).MilestoneRewards,
		QueueMeta = safeRequire(replicatedStorage:FindFirstChild('TS') and replicatedStorage.TS:FindFirstChild('game') and replicatedStorage.TS.game:FindFirstChild('queue-meta')) and safeRequire(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Store = safeRequire(lplr:FindFirstChild('PlayerScripts') and lplr.PlayerScripts:FindFirstChild('TS') and lplr.PlayerScripts.TS:FindFirstChild('ui') and lplr.PlayerScripts.TS.ui:FindFirstChild('store')) and safeRequire(lplr.PlayerScripts.TS.ui.store).ClientStore
	}, {
		__index = function(self, ind)
			if Knit and Knit.Controllers then
				rawset(self, ind, Knit.Controllers[ind])
				return rawget(self, ind)
			end
			return nil
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

for i, v in vape.Modules do
	if v.Category == 'Combat' then
		vape:Remove(i)
	end
end

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
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
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
	local AutoGamble
	
	AutoGamble = vape.Categories.Utility:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)

run(function()
	local AutoQueue
	local QueueType
	local Leave
	
	local Categories = {}
	
	AutoQueue = vape.Categories.Utility:CreateModule({
	    Name = 'AutoQueue',
	    Function = function(call)
	        if call then
	            repeat
	                local partyData = bedwars.Store:getState().Party
	                if partyData.leader.userId == lplr.UserId then
	                    if partyData.queueState == 3 and partyData.queueState ~= Categories[QueueType.Value] then
	                        replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveQueue:FireServer()
	                    elseif partyData.queueState < 2 then
							bedwars.QueueController:joinQueue(Categories[QueueType.Value])
	                        task.wait(1)
	                    end
	                elseif Leave.Enabled then
	                    replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveParty:FireServer()
	                end
	                task.wait(0.1)
	            until not AutoQueue.Enabled
	
	        else
	            replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveQueue:FireServer()
	        end
	    end
	})
	
	local list = {}
	for i,v in bedwars.QueueMeta do
	    if not v.disabled and v.title and not Categories[v.title] then
	        Categories[v.title] = i
	        table.insert(list, v.title)
	    end
	end
	table.sort(list)
	QueueType = AutoQueue:CreateDropdown({
	    Name = 'Queue Type',
	    List = list,
	    Default = 'Duels (2v2)'
	})
	Leave = AutoQueue:CreateToggle({
	    Name = 'Leave Party',
	    Default = true
	})
end)

run(function()
	local ClaimRewards
	local CratesOnly
	local Notify
	
	ClaimRewards = vape.Categories.Utility:CreateModule({
		Name = 'ClaimRewards',
		Function = function(callback)
			if callback then
				repeat
					local level = bedwars.Store:getState().Bedwars.playerLevel or 0
					local claimed = bedwars.MilestonesController.milestoneRewardsClaimed
				if not claimed then
					local state = bedwars.Store:getState().Bedwars
					claimed = state and state.milestoneRewardsClaimed or {}
				end
	
					for _, v in bedwars.MilestoneRewards do
						if v.levelRequirement <= level and not table.find(claimed, v.id) and (not CratesOnly.Enabled or v.instantClaim) then
							if bedwars.Client:Get('ClaimMilestoneReward'):CallServer(v.id) then
								table.insert(claimed, v.id)
								if Notify.Enabled then
									notif('ClaimRewards', `Claimed {v.description or v.id}`, 5)
								end
							end
							task.wait(1)
							if not ClaimRewards.Enabled then break end
						end
					end
	
					task.wait(5)
				until not ClaimRewards.Enabled
			end
		end,
		Tooltip = 'Automatically claims every level milestone reward as soon as you unlock it'
	})
	
	CratesOnly = ClaimRewards:CreateToggle({
		Name = 'Crates only',
		Tooltip = 'Only claims the instant rewards like the lucky and diamond crates, leaves kits and cosmetics alone'
	})
	Notify = ClaimRewards:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Tells you what got claimed'
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
				bedwars.Client:Get('SendUserInputType'):SendToServer({userInputType = Device.Value:upper()})
			else
				bedwars.UserInputController.getUserInputType = old
				bedwars.Client:Get('SendUserInputType'):SendToServer({userInputType = oldDevice})
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
				bedwars.Client:Get('SendUserInputType'):SendToServer({userInputType = val:upper()})
			end
		end
	})
end)

run(function()
	local NameHider
	local Replacement
	local ChatTags
	local Level
	local swapped = setmetatable({}, {__mode = 'k'})
	local watched = setmetatable({}, {__mode = 'k'})
	local patterns = {}
	local plain = {}
	local shortest = math.huge
	local textclasses = {TextLabel = true, TextButton = true, TextBox = true}
	local fake = 'hidden'
	local writing
	local oldUsername, oldDisplayName, oldClanTag, oldLevel
	
	local refreshing = false
	
	local function queueRefresh()
		if refreshing or not NameHider or not NameHider.Enabled then return end
		refreshing = true
	
		task.delay(0.35, function()
			refreshing = false
			if NameHider.Enabled then
				NameHider:Toggle()
				NameHider:Toggle()
			end
		end)
	end
	
	local function isLocal(gameplayer)
		local player = gameplayer:getPlayer()
		return player ~= nil and player.UserId == lplr.UserId
	end
	
	local function getGamePlayerClass()
		local gameplayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(lplr)
		local meta = gameplayer and getmetatable(gameplayer)
		return meta and meta.__index
	end
	
	local function hideObject(object)
		if not textclasses[object.ClassName] then return end
	
		local function apply()
			if writing == object then return end
	
			local text = object.Text
			if type(text) ~= 'string' or #text < shortest then return end
	
			local hit = false
			for _, v in plain do
				if text:find(v, 1, true) then
					hit = true
					break
				end
			end
			if not hit then
				local lower = text:lower()
				for _, v in plain do
					if lower:find(v, 1, true) then
						hit = true
						break
					end
				end
			end
			if not hit then return end
	
			local new = text
			for _, v in patterns do
				if new:find(v) then
					new = new:gsub(v, fake)
				end
			end
			if new == text then return end
	
			swapped[object] = text
			writing = object
			object.Text = new
			writing = nil
	
			if not watched[object] then
				watched[object] = object:GetPropertyChangedSignal('Text'):Connect(apply)
			end
		end
	
		apply()
	end
	
	local function watch(root)
		if not root then return end
	
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		NameHider:Clean(root.DescendantAdded:Connect(function(object)
			if NameHider.Enabled then
				hideObject(object)
			end
		end))
	
		local clock = os.clock()
		for _, v in root:GetDescendants() do
			hideObject(v)
	
			if os.clock() - clock > 0.002 then
				task.wait()
				if not NameHider.Enabled then return end
				clock = os.clock()
	
				if vape.ThreadFix then
					setthreadidentity(8)
				end
			end
		end
	end
	
	NameHider = vape.Categories.Utility:CreateModule({
		Name = 'NameHider',
		Function = function(callback)
			if callback then
				table.clear(patterns)
				table.clear(plain)
				shortest = math.huge
				for _, v in {lplr.Name, lplr.DisplayName} do
					if v ~= '' then
						local low = v:lower()
						if not table.find(plain, low) then
							table.insert(plain, low)
							shortest = math.min(shortest, #low)
						end
					end
					for _, v2 in {v, v:lower(), v:upper()} do
						local pattern = (v2:gsub('%W', '%%%0'))
						if v2 ~= '' and not table.find(patterns, pattern) then
							table.insert(patterns, pattern)
						end
					end
				end
	
				fake = Replacement.Value ~= '' and Replacement.Value or 'hidden'
				for _, v in patterns do
					if fake:find(v) then
						fake = 'hidden'
						break
					end
				end
	
				local gameplayer = getGamePlayerClass()
				if gameplayer and not oldUsername then
					oldUsername, oldDisplayName = gameplayer.getUsername, gameplayer.getDisplayName
					oldClanTag, oldLevel = gameplayer.getClanTag, gameplayer.getLevel
					gameplayer.getUsername = function(self, ...)
						return isLocal(self) and fake or oldUsername(self, ...)
					end
					gameplayer.getDisplayName = function(self, ...)
						return isLocal(self) and fake or oldDisplayName(self, ...)
					end
					gameplayer.getClanTag = function(self, ...)
						return isLocal(self) and ChatTags.Enabled and '' or oldClanTag(self, ...)
					end
					gameplayer.getLevel = function(self, ...)
						return isLocal(self) and Level.Enabled and -1 or oldLevel(self, ...)
					end
				end
	
				for _, v in {lplr:FindFirstChildOfClass('PlayerGui'), coreGui, gethui and gethui() or nil, lplr.Character} do
					watch(v)
				end
	
				NameHider:Clean(lplr.CharacterAdded:Connect(function(char)
					if NameHider.Enabled then
						watch(char)
					end
				end))
			else
				local gameplayer = getGamePlayerClass()
				if oldUsername and gameplayer then
					gameplayer.getUsername, gameplayer.getDisplayName = oldUsername, oldDisplayName
					gameplayer.getClanTag, gameplayer.getLevel = oldClanTag, oldLevel
					oldUsername, oldDisplayName, oldClanTag, oldLevel = nil, nil, nil, nil
				end
				if vape.ThreadFix then
					setthreadidentity(8)
				end
	
				for i, v in watched do
					v:Disconnect()
				end
				table.clear(watched)
	
				for i, v in swapped do
					if i.Parent then
						writing = i
						i.Text = v
					end
				end
				writing = nil
				table.clear(swapped)
			end
		end,
		Tooltip = 'Replaces your username and display name everywhere it shows up on your screen',
		ExtraText = function()
			return Replacement.Value ~= '' and Replacement.Value or 'hidden'
		end
	})
	
	Replacement = NameHider:CreateTextBox({
		Name = 'Name',
		Function = queueRefresh,
		Default = 'hidden'
	})
	ChatTags = NameHider:CreateToggle({
		Name = 'Hide chat tags',
		Tooltip = 'Hides your clan tag wherever it renders'
	})
	Level = NameHider:CreateToggle({
		Name = 'Hide level',
		Tooltip = 'Hides your level wherever it renders'
	})
end)

run(function()
	local SetEmote
	local Emote
	local track
	local billboard
	local moved
	
	local list, old = {}, {}
	for i, v in bedwars.EmoteMeta do
		if i ~= bedwars.EmoteType.NONE and v.name and not old[v.name] then
			old[v.name] = i
			table.insert(list, v.name)
		end
	end
	table.sort(list)
	
	local function cancelEmote()
		if moved then
			moved:Disconnect()
			moved = nil
		end
		if track then
			track:Stop()
			track:Destroy()
			track = nil
		end
		if billboard then
			billboard:Destroy()
			billboard = nil
		end
	
		local maid = bedwars.EmoteController and bedwars.EmoteController.emoteAudioMaids and bedwars.EmoteController.emoteAudioMaids[lplr.UserId]
		if maid then
			maid:DoCleaning()
		end
	
		if entitylib.isAlive and lplr.Character:GetAttribute('PlayingEmote') then
			lplr.Character:SetAttribute('PlayingEmote', nil)
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
						local playBeginSounds = bedwars.EmoteController and (bedwars.EmoteController.createEmoteBeginAudioPlayers or bedwars.EmoteController.playEmoteBeginSounds)
						if playBeginSounds then
							playBeginSounds(bedwars.EmoteController, emoteType, lplr)
						end
						local animation = meta.animation
						if not animation and meta.emoteDisplayType then
							local display = bedwars.EmoteDisplayMeta[meta.emoteDisplayType]
							animation = display and display.animation
						end
						if animation then
							track = lplr.Character.Humanoid:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(animation.type))
							track.Looped = animation.looped or false
							track:Play(nil, nil, animation.speed or 1)
						end
						if not meta.animation then
							local gui = Instance.new('BillboardGui')
							billboard = gui
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
							moved = lplr.Character.Humanoid:GetPropertyChangedSignal('MoveDirection'):Connect(cancelEmote)
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