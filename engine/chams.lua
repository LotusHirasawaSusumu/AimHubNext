-- engine/chams.lua
-- AimHubNext Dual Chams System
-- Green = Visible to local player
-- Red   = Occluded / behind wall
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)
local Styles   = require(script.Parent.Parent.core.styles)
local Utils    = require(script.Parent.Parent.core.utils)

local Chams = {}

-- ==========================================
-- RAYCAST PARAMS (reused, never recreated)
-- ==========================================
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ==========================================
-- INTERNAL: CHECK IF PLAYER IS VISIBLE
-- Reads from cache, never does live raycast here.
-- Cache is populated by BatchUpdateVisibility().
-- ==========================================
local function IsVisibleCached(player)
    -- nil means not yet evaluated this tick, treat as visible
    -- to avoid flickering on first frame
    if State.ChamsVisibilityCache[player] == nil then
        return true
    end
    return State.ChamsVisibilityCache[player]
end

-- ==========================================
-- BATCH VISIBILITY RAYCASTS
-- Called on throttle interval (CHAMS_INTERVAL).
-- Writes results into State.ChamsVisibilityCache.
-- ==========================================
function Chams.BatchUpdateVisibility()
    local Camera   = Services.Camera
    local Players  = Services.Players
    local lp       = Services.LocalPlayer

    if not lp.Character
    or not lp.Character:FindFirstChild("HumanoidRootPart") then
        return
    end

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

        local targetPos = hrp.Position
        local direction = targetPos - origin

        -- Exclude both local char and target char so we don't
        -- hit either player's own parts
        RayParams.FilterDescendantsInstances = {
            lp.Character,
            char,
        }

        local result = workspace:Raycast(origin, direction, RayParams)
        -- If nothing was hit between us and them, they are visible
        State.ChamsVisibilityCache[player] = (result == nil)
    end
end

-- ==========================================
-- APPLY CHAMS VISUALS
-- Reads from cache and updates Highlight instances.
-- Should be called immediately after BatchUpdateVisibility().
-- ==========================================
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

        local existingChams = char:FindFirstChild("AimHubNext_DualChams")

        local shouldShow = S.Enabled
                       and S.ChamsEnabled
                       and hum ~= nil
                       and hum.Health > 0
                       and isEnemy

        if shouldShow then
            -- Create highlight if missing
            if not existingChams then
                existingChams = Instance.new("Highlight")
                existingChams.Name      = "AimHubNext_DualChams"
                existingChams.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                existingChams.Parent    = char
            end

            local visible = IsVisibleCached(player)

            if visible then
                existingChams.FillColor          = S.ChamsVisibleColor
                existingChams.OutlineColor       = S.ChamsVisibleColor
                existingChams.FillTransparency   = S.ChamsVisibleTransparency
                existingChams.OutlineTransparency= 0.1
            else
                existingChams.FillColor          = S.ChamsOccludedColor
                existingChams.OutlineColor       = S.ChamsOccludedColor
                existingChams.FillTransparency   = S.ChamsOccludedTransparency
                existingChams.OutlineTransparency= 0.2
            end

        else
            -- Remove if it shouldn't be shown
            if existingChams then
                existingChams:Destroy()
            end
        end
    end
end

-- ==========================================
-- TICK
-- Called from the main render loop.
-- Handles throttle timing internally.
-- ==========================================
function Chams.Tick(currentTime)
    if not State.Settings.Enabled then return end
    if not State.Settings.ChamsEnabled then
        -- If chams got disabled, clean up immediately
        Utils.WipeAllESPRemnants()
        return
    end

    if currentTime - State.LastChamsUpdate >= State.CHAMS_INTERVAL then
        State.LastChamsUpdate = currentTime
        Chams.BatchUpdateVisibility()
        Chams.ApplyVisuals()
    end
end

-- ==========================================
-- CLEANUP
-- Called by UniversalDestruct.
-- ==========================================
function Chams.Cleanup()
    Utils.WipeAllESPRemnants()
    State.ChamsVisibilityCache = {}
end

return Chams