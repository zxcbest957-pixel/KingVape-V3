local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer

local vape = shared.vape
local SessionInfo = vape.Libraries.sessioninfo

Run(function()
    local Kills = SessionInfo:AddItem("Kills")
    local Eggs = SessionInfo:AddItem("Eggs")
    local Wins = SessionInfo:AddItem("Wins")
    local Games = SessionInfo:AddItem("Games")
end)