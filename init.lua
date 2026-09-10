--!nocheck
local license = ... or {}
license.Key = script_key or license.Key

local cloneref = cloneref or function(ref) return ref end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local downloader = Instance.new('TextLabel')
downloader.Size = UDim2.new(1, 0, 0, 40)
downloader.BackgroundTransparency = 1
downloader.TextStrokeTransparency = 0
downloader.TextSize = 20
downloader.TextColor3 = Color3.new(1, 1, 1)
downloader.Font = Enum.Font.GothamBold
downloader.Text = ''
downloader.Parent = Instance.new('ScreenGui', gethui and gethui() or cloneref(game:GetService('CoreGui')))

local function downloadFile(path, func)
	local content
	if isfile(path) then
		pcall(function() content = readfile(path) end)
	end
	if not content or content == '' or content == '404: Not Found' or typeof(content) ~= 'string' then
		if not license.Closet then
			downloader.Text = 'Downloading '.. path
		end
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
		downloader.Text = ''
	end
	if typeof(content) ~= 'string' then content = '' end
	return (func or function() return content end)(path)
end

local targetCommit = 'main'

local function wipeFolder(path)
	if isfolder(path) then
		pcall(function()
			for _, file in listfiles(path) do
				if isfile(file) and not file:find('color.txt') and not file:find('font.txt') and not file:find('favorites.txt') and not file:find('gui.txt') then
					pcall(delfile, file)
				end
			end
		end)
	end
end

for _, folder in {'catsix', 'catsix/games', 'catsix/profiles', 'catsix/assets', 'catsix/libraries', 'catsix/guis'} do
	if not isfolder(folder) then
		downloader.Text = 'Downloading '.. folder
		makefolder(folder)
	end
end

local currentVersion = (isfile('catsix/profiles/version.txt') and readfile('catsix/profiles/version.txt')) or ''
local targetVersion = '3.0.4'
local currentCommit = (isfile('catsix/profiles/commit.txt') and readfile('catsix/profiles/commit.txt')) or ''
if currentVersion ~= targetVersion or currentCommit ~= targetCommit then
	wipeFolder('catsix/guis')
	wipeFolder('catsix/games')
	wipeFolder('catsix/libraries')
	pcall(delfile, 'catsix/main.lua')
end
pcall(writefile, 'catsix/profiles/commit.txt', targetCommit)
pcall(writefile, 'catsix/profiles/version.txt', targetVersion)

if shared.ForceUpdate or shared.vapereload then
	wipeFolder('catsix/guis')
	wipeFolder('catsix/games')
	wipeFolder('catsix/libraries')
end

local function loadAnalytics()
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
				local fn, err = loadstring(content, 'analytics')
				if fn then
					pcall(fn)
				end
			end
		end)
	end)
end
loadAnalytics()

if shared.updated or #listfiles('catsix/profiles') < 4 then
	shared.VapePresetInstall = function()
		local suc, req = pcall(request, {
			Url = 'https://api.github.com/repos/zxcbest957-pixel/KingVape-V3/contents/profiles',
			Method = 'GET'
		})
		if not suc or req.StatusCode ~= 200 then return false end
		local body = cloneref(game:GetService('HttpService')):JSONDecode(req.Body)
		if not body or typeof(body) ~= 'table' then return false end
		local installed = false
		for _, v in body do
			if v.type == 'file' and pcall(downloadFile, 'catsix/'.. ({v.path:gsub(' ', '%%20')})[1]) then
				installed = true
			end
		end
		return installed
	end
end

downloader.Text = ''
local mainCode = downloadFile('catsix/main.lua')
if typeof(mainCode) == 'string' and mainCode ~= '' then
	local fn = loadstring(mainCode, 'main')
	if fn then
		return fn(license)
	end
end