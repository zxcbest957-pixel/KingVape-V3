local vape = shared.vape
local loadstring = function(...)
    local Chunk, Message = loadstring(...)
    if Message and vape then
        vape:CreateNotification("Vape", `Failed to load : {Message}`, 30, "alert")
    end
    return Chunk
end
local isfile = isfile or function(File: string)
    local Success, Result = pcall(function()
        return readfile(File)
    end)
    return Success and Result ~= nil and Result ~= ""
end
vape.Place = 6872274481
local FilePath: string = `kingvape/games/{vape.Place}.lua`
if not isfile(FilePath) then
    local Success, Result = pcall(function()
        return game:HttpGet(`https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/{select(1, FilePath:gsub("kingvape/", ""))}`, true)
    end)
    if not Success or Result == "404: Not Found" then
        error(Result)
    end

    writefile(FilePath, `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n{Result}`)
end
loadstring(readfile(FilePath), "bedwars")()