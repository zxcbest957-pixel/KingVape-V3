local license = ... or {}
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end
license.Key = license.Key or '_key'

if isfolder('catrewrite') and isfolder('catrewrite/profiles') then
	for _, v in listfiles('catrewrite/profiles') do
		if not v:find('commit.txt') then
			local old = v
			v = v:gsub('catrewrite', 'catsix')
			writefile(v, readfile(old))
		end
	end
	delfolder('catrewrite/profiles')
end

local vape
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
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService("HttpService"))

local function downloadFile(path, func)
	local content
	if isfile(path) then
		pcall(function() content = readfile(path) end)
	end
	if not content or content == '' or content == '404: Not Found' or typeof(content) ~= 'string' then
		local commit = (isfile('catsix/profiles/commit.txt') and readfile('catsix/profiles/commit.txt')) or 'main'
		commit = (commit or 'main'):gsub('%s+', '')
		if commit == '' then commit = 'main' end
		local relPath = select(1, path:gsub('catsix/', ''))
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
	return (func or function() return content end)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('catsix/main.lua'), 'main')(_scriptconfig)
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/'..readfile('catsix/profiles/commit.txt')..'/init.lua', true), 'init')(_scriptconfig)
				end
			]]
			local teleportConfig = httpService:JSONEncode(license)
			teleportConfig = teleportConfig:gsub('":true', "=true"):gsub('{"', '{')
			teleportConfig = teleportConfig:gsub(',"', ','):gsub('":', '=')
			teleportConfig = teleportConfig:gsub('%[', '{'):gsub('%]', '}')
			teleportScript = teleportScript:gsub('_key', tostring(license.Key or '_key'))
			teleportScript = teleportScript:gsub('_scriptconfig', teleportConfig)
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		local keybindStr = 'RIGHTSHIFT'
		if type(vape.Keybind) == 'table' and #vape.Keybind > 0 then
			keybindStr = table.concat(vape.Keybind, ' + '):upper()
		elseif vape.GUIBind and type(vape.GUIBind.Keys) == 'table' and #vape.GUIBind.Keys > 0 then
			keybindStr = table.concat(vape.GUIBind.Keys, ' + '):upper()
		elseif type(vape.Keybind) == 'string' and vape.Keybind ~= '' then
			keybindStr = vape.Keybind:upper()
		end
		vape:CreateNotification('KingVape', (vape.VapeButton and 'Press the button in the top right' or 'Press '..keybindStr)..' to open GUI', 5)
		task.delay(0.05 + cloneref(game:GetService('RunService')).PostSimulation:Wait(), function()
			if shared.updated then
				vape:CreateNotification('KingVape', `Script has updated to {(readfile('catsix/profiles/commit.txt') or ""):sub(1, 8)}`, 10, 'info')
			end
		end)
	end
end

if not isfile('catsix/profiles/gui.txt') then
	writefile('catsix/profiles/gui.txt', 'new')
end
local gui = 'new'

if not isfolder('catsix/assets/'..gui) then
	makefolder('catsix/assets/'..gui)
end
vape = loadstring(downloadFile('catsix/guis/'..gui..'.lua'), 'gui')(license)
shared.vape = vape
shared.vapesmooth = true
_G.vape = vape
getgenv().used_init = true

if hookmetamethod and not getgenv().run then
	getgenv().run = true
	local old; old = hookmetamethod(game, '__namecall', function(self, Remote, ...)
		if not checkcaller() and getnamecallmethod() == 'FireServer' then
			if typeof(Remote) == "Instance" and Remote.Name == 'TabFreezeAnticheat_ClientToServerReport' then
				return
			end
		end
		return old(self, Remote, ...)
	end)
end

task.spawn(function()
	pcall(function()
		if shared.KingVapeAnalyticsLoaded then return end
		shared.KingVapeAnalyticsLoaded = true
		local path = 'catsix/libraries/analytics.lua'
		local content
		
		if isfile(path) and not shared.ForceUpdate then
			pcall(function() content = readfile(path) end)
		end
		
		if not content or content == '' or content:find('404: Not Found') or content:find('ВСТАВЬТЕ_СЮДА') then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/libraries/analytics.lua?t='..tostring(math.floor(os.time() / 10)), true)
			end)
			if suc and res and res ~= '' and not res:find('404: Not Found') then
				content = res
				pcall(writefile, path, res)
			end
		end
		
		if content and content ~= '' and not content:find('404: Not Found') then
			local fn = loadstring(content, 'analytics')
			if fn then pcall(fn) end
		end
	end)
end)

if not shared.VapeIndependent then
	loadstring(downloadFile('catsix/games/universal.lua'), 'universal')(license)
	if isfile('catsix/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('catsix/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(license)
	else
		pcall(function()
			loadstring(downloadFile('catsix/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(license)
		end)
	end
	if isfile('catsix/libraries/main.lua') then
		loadstring(downloadFile('catsix/libraries/main.lua'), 'main')(license)
	elseif isfile('catsix/libraries/premium.lua') then
		loadstring(downloadFile('catsix/libraries/premium.lua'), 'premium')(license)
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end