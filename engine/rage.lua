-- engine/rage.lua
-- AimHubNext Rage Mode Systems
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Utils    = require("core/utils.lua")

local Rage = {}

local function ExpandHitboxes()
    local lp = Services.LocalPlayer
    local S  = State.Settings
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then continue end
        if Utils.IsTeammate(player) then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local expandSize = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
        for _, partName in ipairs({ "Head", "HumanoidRootPart" }) do
            local part = char:FindFirstChild(partName)
            if not part or not part:IsA("BasePart") then continue end
            if not State.OriginalSizes[part] then
                State.OriginalSizes[part] = part.Size
            end
            if S.HitboxExpander and S.RageEnabled then
                pcall(function()
                    part.Size         = expandSize
                    part.CanCollide   = false
                    part.Transparency = partName == "Head" and 0.7 or 0.8
                end)
            else
                pcall(function()
                    part.Size         = State.OriginalSizes[part]
                    part.Transparency = partName == "Head" and 0 or 1
                end)
            end
        end
    end
end

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
        local ec = player.Character
        if not ec then continue end
        if Utils.IsTeammate(player) then continue end
        local ehrp = ec:FindFirstChild("HumanoidRootPart")
        local hum  = ec:FindFirstChildOfClass("Humanoid")
        if not ehrp or not hum or hum.Health <= 0 then continue end
        if (ehrp.Position - myPos).Magnitude <= S.KillAuraRange then
            if tool then pcall(function() tool:Activate() end)
            else
                Utils.ControlClick(true)
                task.defer(function() Utils.ControlClick(false) end)
            end
            break
        end
    end
end

function Rage.GetRageHitPart(character)
    if not character then return nil end
    local mode = State.Settings.AutoHitbox
    if mode == "Random" then
        local candidates = { "Head","HumanoidRootPart","UpperTorso","LowerTorso" }
        local valid = {}
        for _, name in ipairs(candidates) do
            if character:FindFirstChild(name) then
                table.insert(valid, name)
            end
        end
        if #valid > 0 then
            return character:FindFirstChild(valid[math.random(1, #valid)])
        end
        return character:FindFirstChild("HumanoidRootPart")
    elseif mode == "Torso" then
        return character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChild("UpperTorso")
    else
        return character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
    end
end

function Rage.Tick(currentTime)
    local S = State.Settings
    if not S.RageEnabled then
        if next(State.OriginalSizes) ~= nil then
            Utils.ResetHitboxes()
        end
        return
    end
    if currentTime - State.LastHitboxUpdate >= State.HITBOX_INTERVAL then
        State.LastHitboxUpdate = currentTime
        ExpandHitboxes()
    end
    if currentTime - State.LastKillAuraUpdate >= State.KILLAURA_INTERVAL then
        State.LastKillAuraUpdate = currentTime
        RunKillAura()
    end
end

function Rage.Cleanup()
    Utils.ResetHitboxes()
end

return Rage