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
vape.Place = 6872274481
local path = 'catsix/games/'..vape.Place..'.lua'
if not isfile(path) then
	local suc, res = pcall(function()
		local commit = (isfile('catsix/profiles/commit.txt') and readfile('catsix/profiles/commit.txt')) or 'main'
			if not commit or commit == '' then commit = 'main' end
			return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/'..commit..'/'..select(1, path:gsub('catsix/', '')), true)
	end)
	if not suc or res == '404: Not Found' then
		error(res)
	end

	writefile(path, '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res)
end
loadstring(readfile(path), 'bedwars')()