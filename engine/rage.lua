-- engine/rage.lua
-- AimHubNext Rage Mode Systems
-- Hitbox Expander + Kill Aura
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)
local Utils    = require(script.Parent.Parent.core.utils)

local Rage = {}

-- ==========================================
-- HITBOX EXPANDER
-- Expands Head and HumanoidRootPart size
-- on enemy characters client-side.
-- Throttled to HITBOX_INTERVAL seconds.
-- ==========================================
local function ExpandHitboxes()
    local Players = Services.Players
    local lp      = Services.LocalPlayer
    local S       = State.Settings

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end

        local char = player.Character
        if not char then continue end

        -- Skip teammates
        if Utils.IsTeammate(player) then continue end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local expandSize = Vector3.new(
            S.HitboxSize,
            S.HitboxSize,
            S.HitboxSize
        )

        for _, partName in ipairs({ "Head", "HumanoidRootPart" }) do
            local part = char:FindFirstChild(partName)
            if not part or not part:IsA("BasePart") then continue end

            -- Save original size once
            if not State.OriginalSizes[part] then
                State.OriginalSizes[part] = part.Size
            end

            if S.HitboxExpander and S.RageEnabled then
                pcall(function()
                    part.Size         = expandSize
                    part.CanCollide   = false
                    part.Transparency = (partName == "Head") and 0.7 or 0.8
                end)
            else
                -- Restore if rage/hitbox got toggled off
                pcall(function()
                    part.Size         = State.OriginalSizes[part]
                    part.Transparency = (partName == "Head") and 0 or 1
                end)
            end
        end
    end
end

-- ==========================================
-- KILL AURA
-- Attacks the nearest enemy within range.
-- Only triggers one attack per cycle to
-- reduce server load.
-- Throttled to KILLAURA_INTERVAL seconds.
-- ==========================================
local function RunKillAura()
    local S  = State.Settings
    local lp = Services.LocalPlayer

    if not S.KillAura or not S.RageEnabled then return end

    local char = lp.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local myPos = hrp.Position
    local tool  = char:FindFirstChildOfClass("Tool")

    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player == lp then continue end

        local enemyChar = player.Character
        if not enemyChar then continue end

        -- Skip teammates
        if Utils.IsTeammate(player) then continue end

        local enemyHRP = enemyChar:FindFirstChild("HumanoidRootPart")
        local hum      = enemyChar:FindFirstChildOfClass("Humanoid")

        if not enemyHRP or not hum or hum.Health <= 0 then continue end

        local dist = (enemyHRP.Position - myPos).Magnitude

        if dist <= S.KillAuraRange then
            if tool then
                -- Prefer Tool:Activate for game-compatible attack
                pcall(function() tool:Activate() end)
            else
                Utils.ControlClick(true)
                task.defer(function()
                    Utils.ControlClick(false)
                end)
            end
            -- Only attack one target per cycle
            break
        end
    end
end

-- ==========================================
-- GET RAGE HIT PART
-- Returns the BasePart to aim at in rage mode
-- based on AutoHitbox setting.
-- ==========================================
function Rage.GetRageHitPart(character)
    if not character then return nil end

    local mode = State.Settings.AutoHitbox

    if mode == "Random" then
        local candidates = {
            "Head",
            "HumanoidRootPart",
            "UpperTorso",
            "LowerTorso",
        }
        -- Filter to only existing parts
        local valid = {}
        for _, name in ipairs(candidates) do
            if character:FindFirstChild(name) then
                table.insert(valid, name)
            end
        end
        if #valid > 0 then
            return character:FindFirstChild(
                valid[math.random(1, #valid)]
            )
        end
        return character:FindFirstChild("HumanoidRootPart")

    elseif mode == "Torso" then
        return character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")

    else
        -- Default: Head
        return character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
    end
end

-- ==========================================
-- TICK
-- Called from the main render loop.
-- Handles throttle timing internally.
-- ==========================================
function Rage.Tick(currentTime)
    local S = State.Settings

    -- Nothing to do if rage is off
    if not S.RageEnabled then
        -- Make sure hitboxes are restored when rage turns off
        if next(State.OriginalSizes) ~= nil then
            Utils.ResetHitboxes()
        end
        return
    end

    -- Throttled hitbox update
    if currentTime - State.LastHitboxUpdate >= State.HITBOX_INTERVAL then
        State.LastHitboxUpdate = currentTime
        ExpandHitboxes()
    end

    -- Throttled kill aura
    if currentTime - State.LastKillAuraUpdate >= State.KILLAURA_INTERVAL then
        State.LastKillAuraUpdate = currentTime
        RunKillAura()
    end
end

-- ==========================================
-- CLEANUP
-- Restore all hitboxes on unload.
-- ==========================================
function Rage.Cleanup()
    Utils.ResetHitboxes()
end

return Rage