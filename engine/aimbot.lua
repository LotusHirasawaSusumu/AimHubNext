-- engine/aimbot.lua
-- AimHubNext Aimbot Core
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Utils    = require("core/utils.lua")
local Drawings = require("engine/drawings.lua")
local Rage     = require("engine/rage.lua")

local Aimbot = {}

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsVisible(player)
    local lp   = Services.LocalPlayer
    local char = player.Character
    if not char then return false end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local cached = State.ChamsVisibilityCache[player]
    if cached ~= nil then return cached end
    RayParams.FilterDescendantsInstances = { lp.Character, char }
    local origin = Services.Camera.CFrame.Position
    local result = workspace:Raycast(origin, hrp.Position - origin, RayParams)
    return result == nil
end

function Aimbot.GetClosestPlayer()
    local S       = State.Settings
    local lp      = Services.LocalPlayer
    local lpChar  = lp.Character
    if not lpChar or not lpChar:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos       = lpChar.HumanoidRootPart.Position
    local bestTarget  = nil
    local bestPriority= math.huge
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player == lp then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        if Utils.IsTeammate(player) then continue end
        local dist = (hrp.Position - myPos).Magnitude
        if dist > S.MaxDistance then continue end
        if S.FOVCheckEnabled then
            if Utils.GetScreenFOVDistance(player) > S.FOVRadius then continue end
        end
        if S.WallCheck then
            if not IsVisible(player) then continue end
        end
        local priority = 0
        if S.TargetPriority == "Distance" then
            priority = dist
        elseif S.TargetPriority == "Health" then
            priority = hum.Health
        elseif S.TargetPriority == "FOV" then
            priority = Utils.GetScreenFOVDistance(player)
        end
        if priority < bestPriority then
            bestPriority = priority
            bestTarget   = player
        end
    end
    return bestTarget
end

local function StopShooting()
    if State.IsShooting then
        State.IsShooting = false
        Utils.ControlClick(false)
    end
end

local function RunAutoShootLoop()
    if State.IsShooting then return end
    State.IsShooting = true
    task.spawn(function()
        local fireRates = State.FireRates
        while State.Aiming and State.Target and State.Settings.AutoShoot do
            local rate = fireRates[State.Settings.ShootMode] or fireRates.Normal
            Utils.ControlClick(true)
            task.wait(rate.press)
            if not (State.Aiming and State.Target and State.Settings.AutoShoot) then
                break
            end
            Utils.ControlClick(false)
            task.wait(rate.release)
        end
        Utils.ControlClick(false)
        State.IsShooting = false
    end)
end

local function ValidateTarget()
    local target = State.Target
    if not target then return false end
    local char = target.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    if Utils.IsTeammate(target) then return false end
    if State.Settings.WallCheck then
        local cached = State.ChamsVisibilityCache[target]
        if cached == false then return false end
    end
    if State.Settings.FOVCheckEnabled then
        if Utils.GetScreenFOVDistance(target) > State.Settings.FOVRadius * 1.5 then
            return false
        end
    end
    return true
end

local function GetHitPosition(hitPart)
    local S   = State.Settings
    local pos = hitPart.Position
    if S.Prediction > 0 and hitPart:IsA("BasePart") then
        pos = pos + hitPart.AssemblyLinearVelocity * (S.Prediction / 60)
    end
    if S.ResolverEnabled and S.RageEnabled and State.Target then
        local realHead = State.Target.Character
            and State.Target.Character:FindFirstChild("Head")
        if realHead then
            pos = realHead.Position
            if S.Prediction > 0 then
                pos = pos + realHead.AssemblyLinearVelocity * (S.Prediction / 60)
            end
        end
    end
    return pos
end

local function SteerCamera(targetPos, dt)
    local S      = State.Settings
    local Camera = Services.Camera
    if S.SilentAim then return end
    local targetLook = CFrame.lookAt(Camera.CFrame.Position, targetPos)
    if S.RageEnabled and S.SnapAim then
        Camera.CFrame = targetLook
    else
        local alpha = 1 - math.pow(
            1 - math.clamp(S.Smoothness / 100, 0.001, 1),
            dt * 60
        )
        Camera.CFrame = Camera.CFrame:Lerp(targetLook, alpha)
    end
end

Aimbot.SystemLogEvent = function(msg) end

function Aimbot.Tick(dt)
    local S = State.Settings
    if not S.Enabled or not State.Aiming then
        State.Target = nil
        Drawings.HideIndicators()
        StopShooting()
        State.LastLoggedTarget = nil
        return
    end
    if not ValidateTarget() then
        State.Target = Aimbot.GetClosestPlayer()
    end
    if not State.Target or not State.Target.Character then
        Drawings.HideIndicators()
        StopShooting()
        return
    end
    local hitPart
    if S.RageEnabled then
        hitPart = Rage.GetRageHitPart(State.Target.Character)
    else
        hitPart = State.Target.Character:FindFirstChild(S.TargetPart)
               or State.Target.Character:FindFirstChild("HumanoidRootPart")
    end
    if not hitPart then
        Drawings.HideIndicators()
        StopShooting()
        return
    end
    local targetPos = GetHitPosition(hitPart)
    Drawings.UpdateTargetIndicator(targetPos)
    if State.Target ~= State.LastLoggedTarget then
        Aimbot.SystemLogEvent("Locked: " .. State.Target.DisplayName)
        State.LastLoggedTarget = State.Target
    end
    local hum       = State.Target.Character:FindFirstChildOfClass("Humanoid")
    local currentHp = hum and hum.Health or 0
    if currentHp <= 0 and State.LastTargetHealth > 0 then
        Aimbot.SystemLogEvent("Eliminated: " .. State.Target.DisplayName)
        State.LastLoggedTarget = nil
        if S.AutoSwitch then
            State.Target = nil
            StopShooting()
            Drawings.HideIndicators()
            State.LastTargetHealth = 0
            return
        end
    end
    State.LastTargetHealth = currentHp
    SteerCamera(targetPos, dt)
    if S.AutoShoot then RunAutoShootLoop() end
end

function Aimbot.Cleanup()
    StopShooting()
    State.Target           = nil
    State.LastLoggedTarget = nil
    State.LastTargetHealth = 0
end

return Aimbot