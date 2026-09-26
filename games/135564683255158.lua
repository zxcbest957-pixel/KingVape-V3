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
local function DownloadFile(FilePath: string, Func)
    if not isfile(FilePath) then
        local Success, Result = pcall(function()
            return game:HttpGet(`https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/{select(1, FilePath:gsub("kingvape/", ""))}`, true)
        end)
        if not Success or Result == "404: Not Found" then
            error(Result)
        end
        if FilePath:find(".lua") then
            Result = `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n{Result}`
        end
        writefile(FilePath, Result)
    end
    return (Func or readfile)(FilePath)
end

vape.Place = 155615604
loadstring(DownloadFile(`kingvape/games/{vape.Place}.lua`), "prison life")()