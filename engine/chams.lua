-- engine/chams.lua
-- AimHubNext Dual Chams System
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Utils    = require("core/utils.lua")

local Chams = {}

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisibleCached(player)
    if State.ChamsVisibilityCache[player] == nil then return true end
    return State.ChamsVisibilityCache[player]
end

function Chams.BatchUpdateVisibility()
    local Camera  = Services.Camera
    local Players = Services.Players
    local lp      = Services.LocalPlayer
    if not lp.Character
    or not lp.Character:FindFirstChild("HumanoidRootPart") then return end
    local origin = Camera.CFrame.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then
            State.ChamsVisibilityCache[player] = false
            continue
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            State.ChamsVisibilityCache[player] = false
            continue
        end
        RayParams.FilterDescendantsInstances = { lp.Character, char }
        local result = workspace:Raycast(
            origin, hrp.Position - origin, RayParams
        )
        State.ChamsVisibilityCache[player] = (result == nil)
    end
end

function Chams.ApplyVisuals()
    local Players = Services.Players
    local lp      = Services.LocalPlayer
    local S       = State.Settings
    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then continue end
        local hum     = char:FindFirstChildOfClass("Humanoid")
        local isEnemy = not Utils.IsTeammate(player)
        local existing = char:FindFirstChild("AimHubNext_DualChams")
        local shouldShow = S.Enabled and S.ChamsEnabled
                       and hum ~= nil and hum.Health > 0 and isEnemy
        if shouldShow then
            if not existing then
                existing = Instance.new("Highlight")
                existing.Name      = "AimHubNext_DualChams"
                existing.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                existing.Parent    = char
            end
            if IsVisibleCached(player) then
                existing.FillColor           = S.ChamsVisibleColor
                existing.OutlineColor        = S.ChamsVisibleColor
                existing.FillTransparency    = S.ChamsVisibleTransparency
                existing.OutlineTransparency = 0.1
            else
                existing.FillColor           = S.ChamsOccludedColor
                existing.OutlineColor        = S.ChamsOccludedColor
                existing.FillTransparency    = S.ChamsOccludedTransparency
                existing.OutlineTransparency = 0.2
            end
        else
            if existing then existing:Destroy() end
        end
    end
end

function Chams.Tick(currentTime)
    if not State.Settings.Enabled then return end
    if not State.Settings.ChamsEnabled then
        Utils.WipeAllESPRemnants()
        return
    end
    if currentTime - State.LastChamsUpdate >= State.CHAMS_INTERVAL then
        State.LastChamsUpdate = currentTime
        Chams.BatchUpdateVisibility()
        Chams.ApplyVisuals()
    end
end

function Chams.Cleanup()
    Utils.WipeAllESPRemnants()
    State.ChamsVisibilityCache = {}
end

return Chams