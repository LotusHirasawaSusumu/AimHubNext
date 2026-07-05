-- core/services.lua
-- AimHubNext Roblox Service References
-- Mod Author: CookieLee
-- No dependencies, no require needed.

local Services = {}

Services.Players          = game:GetService("Players")
Services.RunService       = game:GetService("RunService")
Services.TweenService     = game:GetService("TweenService")
Services.UserInputService = game:GetService("UserInputService")
Services.LocalPlayer      = Services.Players.LocalPlayer
Services.Camera           = workspace.CurrentCamera
Services.PlayerGui        = Services.LocalPlayer:WaitForChild("PlayerGui")

return Services