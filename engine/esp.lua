-- engine/esp.lua
-- AimHubNext Legacy ESP System
-- Single-color team-based highlight fallback.
-- Only active when ChamsEnabled = false.
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)
local Styles   = require(script.Parent.Parent.core.styles)
local Utils    = require(script.Parent.Parent.core.utils)

local ESP = {}

-- Internal name tag used on Highlight instances
local ESP_TAG = "AimHubNext_ESP"

-- ==========================================
-- APPLY LEGACY ESP VISUALS
-- Creates/updates simple Highlight instances.
-- No raycast — pure visibility highlight.
-- Called every frame from render loop,
-- but only when ChamsEnabled is false.
-- ==========================================
function ESP.ApplyVisuals()
    local Players = Services.Players
    local Camera  = Services.Camera
    local lp      = Services.LocalPlayer
    local S       = State.Settings

    -- Guard: only run when legacy ESP is the active visual mode
    if not S.Enabled or not S.ESPEnabled or S.ChamsEnabled then
        -- If switching away, clean up our highlights
        ESP.Cleanup()
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end

        local char = player.Character
        if not char then continue end

        local hrp  = char:FindFirstChild("HumanoidRootPart")
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local isEnemy = not Utils.IsTeammate(player)

        local highlight = char:FindFirstChild(ESP_TAG)

        local shouldShow = hrp ~= nil
                       and hum ~= nil
                       and hum.Health > 0
                       and isEnemy

        if shouldShow then
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name               = ESP_TAG
                highlight.OutlineTransparency= 0.2
                highlight.Parent             = char
            end

            -- Use team color if available, otherwise fall back to accent
            local col = Styles.Accent
            if player.TeamColor then
                col = player.TeamColor.Color
            end

            highlight.FillTransparency = S.ESPTransparency
            highlight.FillColor        = col
            highlight.OutlineColor     = col
        else
            if highlight then
                highlight:Destroy()
            end
        end
    end
end

-- ==========================================
-- CLEANUP
-- Removes all legacy ESP highlights from all characters.
-- ==========================================
function ESP.Cleanup()
    local Players = Services.Players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local highlight = player.Character:FindFirstChild(ESP_TAG)
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
        end
    end
end

-- ==========================================
-- TICK
-- Called from the main render loop every frame.
-- Lightweight enough to not need throttling
-- since it only reads cached team data.
-- ==========================================
function ESP.Tick()
    ESP.ApplyVisuals()
end

return ESP