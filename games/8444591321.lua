local license = ... or {}
local vape = shared.vape
local loadstring = function(...)
	local str = ...
	if typeof(str) ~= 'string' or str == '' then return function() end end
	str = str:gsub('\239\187\191', ''):gsub('\239\191\189', '')
	local res, err = loadstring(str, select(2, ...))
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res or function() end
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
vape.Place = 6872274481
local path = 'kingvape/games/'..vape.Place..'.lua'
local content = nil
if isfile(path) then
	pcall(function() content = readfile(path) end)
end
if not content or content == '' or content == '404: Not Found' then
	local suc, res = pcall(function()
		local commit = (isfile('kingvape/profiles/commit.txt') and readfile('kingvape/profiles/commit.txt')) or 'main'
		if not commit or commit == '' then commit = 'main' end
		return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/'..commit..'/'..select(1, path:gsub('kingvape/', '')), true)
	end)
	if suc and res and res ~= '404: Not Found' and res ~= '' then
		content = res
		pcall(writefile, path, '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res)
	end
end
if content and content ~= '' then
	local fn = loadstring(content, 'bedwars')
	if fn then fn(license) end
end