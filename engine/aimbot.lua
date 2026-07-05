-- engine/aimbot.lua
-- AimHubNext Aimbot Core
-- Target acquisition, camera steering,
-- auto-shoot orchestration.
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)
local Styles   = require(script.Parent.Parent.core.styles)
local Utils    = require(script.Parent.Parent.core.utils)
local Drawings = require(script.Parent.drawings)
local Rage     = require(script.Parent.rage)

local Aimbot = {}

-- ==========================================
-- RAYCAST PARAMS (module-local, reused)
-- ==========================================
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude

-- ==========================================
-- WALL CHECK (live, used when cache is nil)
-- ==========================================
local function IsVisible(player)
    local lp     = Services.LocalPlayer
    local Camera = Services.Camera

    local char = player.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Use chams cache when available
    local cached = State.ChamsVisibilityCache[player]
    if cached ~= nil then return cached end

    -- Fallback live raycast
    RayParams.FilterDescendantsInstances = {
        lp.Character,
        char,
    }
    local origin    = Camera.CFrame.Position
    local direction = hrp.Position - origin
    local result    = workspace:Raycast(origin, direction, RayParams)
    return result == nil
end

-- ==========================================
-- GET CLOSEST VALID PLAYER
-- Respects FOV, wall check, max distance,
-- team check and target priority setting.
-- ==========================================
function Aimbot.GetClosestPlayer()
    local S       = State.Settings
    local lp      = Services.LocalPlayer
    local Camera  = Services.Camera
    local Players = Services.Players

    local lpChar = lp.Character
    if not lpChar or not lpChar:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local myPos       = lpChar.HumanoidRootPart.Position
    local bestTarget  = nil
    local bestPriority= math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end

        local char = player.Character
        if not char then continue end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not hrp or not hum or hum.Health <= 0 then continue end

        -- Team filter
        if Utils.IsTeammate(player) then continue end

        -- Distance filter
        local distance = (hrp.Position - myPos).Magnitude
        if distance > S.MaxDistance then continue end

        -- FOV filter
        if S.FOVCheckEnabled then
            local fovDist = Utils.GetScreenFOVDistance(player)
            if fovDist > S.FOVRadius then continue end
        end

        -- Wall check filter
        if S.WallCheck then
            if not IsVisible(player) then continue end
        end

        -- Priority scoring
        local priority = 0
        if S.TargetPriority == "Distance" then
            priority = distance
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

-- ==========================================
-- AUTO SHOOT LOOP
-- Runs in a separate task.spawn thread.
-- Exits when aiming stops or target lost.
-- ==========================================
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

-- ==========================================
-- STOP SHOOTING
-- ==========================================
local function StopShooting()
    if State.IsShooting then
        State.IsShooting = false
        Utils.ControlClick(false)
    end
end

-- ==========================================
-- VALIDATE CURRENT TARGET
-- Returns true if State.Target is still
-- a valid, living, in-range enemy.
-- ==========================================
local function ValidateCurrentTarget()
    local target = State.Target
    if not target then return false end

    local char = target.Character
    if not char then return false end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")

    if not hrp or not hum or hum.Health <= 0 then return false end
    if Utils.IsTeammate(target) then return false end

    -- Check cached wall visibility
    if State.Settings.WallCheck then
        local cached = State.ChamsVisibilityCache[target]
        if cached == false then return false end
    end

    -- Check FOV drift (1.5x radius tolerance before reacquiring)
    if State.Settings.FOVCheckEnabled then
        local fovDist = Utils.GetScreenFOVDistance(target)
        if fovDist > State.Settings.FOVRadius * 1.5 then return false end
    end

    return true
end

-- ==========================================
-- GET HIT POSITION
-- Returns world position to aim at,
-- applying prediction offset if enabled.
-- ==========================================
local function GetHitPosition(hitPart)
    local S   = State.Settings
    local pos = hitPart.Position

    if S.Prediction > 0 and hitPart:IsA("BasePart") then
        pos = pos + (hitPart.AssemblyLinearVelocity * (S.Prediction / 60))
    end

    -- Resolver: override to real head position
    if S.ResolverEnabled and S.RageEnabled and State.Target then
        local char    = State.Target.Character
        local realHead= char and char:FindFirstChild("Head")
        if realHead then
            pos = realHead.Position
            if S.Prediction > 0 then
                pos = pos + (realHead.AssemblyLinearVelocity * (S.Prediction / 60))
            end
        end
    end

    return pos
end

-- ==========================================
-- STEER CAMERA TOWARD TARGET
-- Respects SilentAim (no camera move),
-- SnapAim (instant), and smooth lerp.
-- ==========================================
local function SteerCamera(targetPos, dt)
    local S      = State.Settings
    local Camera = Services.Camera

    -- Silent aim: camera stays, only mouse.Hit is redirected by hook
    if S.SilentAim then return end

    local targetLook = CFrame.lookAt(Camera.CFrame.Position, targetPos)

    if S.RageEnabled and S.SnapAim then
        Camera.CFrame = targetLook
    else
        local rawSmooth      = math.clamp(S.Smoothness / 100, 0.001, 1)
        local fpsAdjustedAlpha = 1 - math.pow(1 - rawSmooth, dt * 60)
        Camera.CFrame = Camera.CFrame:Lerp(targetLook, fpsAdjustedAlpha)
    end
end

-- ==========================================
-- LOG EVENT CALLBACK
-- Assigned externally by the UI log module.
-- ==========================================
Aimbot.SystemLogEvent = function(msg) end

-- ==========================================
-- TICK
-- Called every frame from the render loop.
-- Full aimbot pipeline:
--   1. Validate / reacquire target
--   2. Compute hit position
--   3. Update indicators
--   4. Steer camera
--   5. Manage auto-shoot
-- ==========================================
function Aimbot.Tick(dt)
    local S = State.Settings

    -- Master guard
    if not S.Enabled or not State.Aiming then
        State.Target = nil
        Drawings.HideIndicators()
        StopShooting()
        State.LastLoggedTarget = nil
        return
    end

    -- Step 1: Validate or reacquire target
    if not ValidateCurrentTarget() then
        State.Target = Aimbot.GetClosestPlayer()
    end

    -- Step 2: If no target found, clean up and exit
    if not State.Target or not State.Target.Character then
        Drawings.HideIndicators()
        StopShooting()
        return
    end

    -- Step 3: Resolve hit part
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

    -- Step 4: Get aim position with prediction + resolver
    local targetPos = GetHitPosition(hitPart)

    -- Step 5: Target indicator + snap line
    Drawings.UpdateTargetIndicator(targetPos)

    -- Step 6: Kill logging
    if State.Target ~= State.LastLoggedTarget then
        Aimbot.SystemLogEvent("Locked: " .. State.Target.DisplayName)
        State.LastLoggedTarget = State.Target
    end

    -- Step 7: Kill tracking (auto-switch on elimination)
    local hum         = State.Target.Character:FindFirstChildOfClass("Humanoid")
    local currentHp   = hum and hum.Health or 0
    if currentHp <= 0 and State.LastTargetHealth > 0 then
        Aimbot.SystemLogEvent("Eliminated: " .. State.Target.DisplayName)
        State.LastLoggedTarget = nil
        if S.AutoSwitch then
            State.Target = nil
            StopShooting()
            Drawings.HideIndicators()
            return
        end
    end
    State.LastTargetHealth = currentHp

    -- Step 8: Steer camera
    SteerCamera(targetPos, dt)

    -- Step 9: Auto shoot
    if S.AutoShoot then
        RunAutoShootLoop()
    end
end

-- ==========================================
-- CLEANUP
-- Called by UniversalDestruct.
-- ==========================================
function Aimbot.Cleanup()
    StopShooting()
    State.Target           = nil
    State.LastLoggedTarget = nil
    State.LastTargetHealth = 0
end

return Aimbot