-- engine/esp.lua
-- AimHubNext Legacy ESP
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Styles   = require("core/styles.lua")
local Utils    = require("core/utils.lua")

local ESP = {}
local ESP_TAG = "AimHubNext_ESP"

function ESP.ApplyVisuals()
    local Players = Services.Players
    local lp      = Services.LocalPlayer
    local S       = State.Settings
    if not S.Enabled or not S.ESPEnabled or S.ChamsEnabled then
        ESP.Cleanup()
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then continue end
        local hrp       = char:FindFirstChild("HumanoidRootPart")
        local hum       = char:FindFirstChildOfClass("Humanoid")
        local isEnemy   = not Utils.IsTeammate(player)
        local highlight = char:FindFirstChild(ESP_TAG)
        local shouldShow = hrp ~= nil and hum ~= nil
                       and hum.Health > 0 and isEnemy
        if shouldShow then
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name                = ESP_TAG
                highlight.OutlineTransparency = 0.2
                highlight.Parent              = char
            end
            local col = Styles.Accent
            if player.TeamColor then col = player.TeamColor.Color end
            highlight.FillTransparency = S.ESPTransparency
            highlight.FillColor        = col
            highlight.OutlineColor     = col
        else
            if highlight then highlight:Destroy() end
        end
    end
end

function ESP.Cleanup()
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player.Character then
            local h = player.Character:FindFirstChild(ESP_TAG)
            if h then pcall(function() h:Destroy() end) end
        end
    end
end

function ESP.Tick()
    ESP.ApplyVisuals()
end

return ESP