-- engine/antiaim.lua
-- AimHubNext Anti-Aim System (CS2-Style)
-- Supports: Spin, Jitter, SideWays, BackWards,
--           HalfSideWays, FakeDown, FakeUp, Random
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)

local AntiAim = {}

-- ==========================================
-- INTERNAL RUNTIME STATE
-- Kept local to this module, mirrored into
-- State for cross-module reads if needed.
-- ==========================================
local angle       = 0   -- cumulative yaw for Spin/FakeDown/FakeUp
local jitterState = false
local switchTimer = 0

-- ==========================================
-- INTERNAL: APPLY CFRAME TO HRP
-- Always preserves world position,
-- only overwrites rotation.
-- ==========================================
local function ApplyRotation(hrp, pitchRad, yawRad, rollRad)
    local pos = hrp.Position
    hrp.CFrame = CFrame.new(pos)
              * CFrame.Angles(pitchRad, yawRad, rollRad or 0)
end

-- ==========================================
-- MODE HANDLERS
-- Each receives (hrp, dt, S) where:
--   hrp = HumanoidRootPart
--   dt  = deltaTime
--   S   = State.Settings
-- ==========================================
local ModeHandlers = {}

-- Classic spinbot: continuous yaw rotation
ModeHandlers["Spin"] = function(hrp, dt, S)
    angle = angle + (S.AntiAimSpeed * dt * 360)
    if angle > 360 then angle = angle - 360 end
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), math.rad(angle))
end

-- CS2-style jitter: rapid 180 degree flicks
ModeHandlers["Jitter"] = function(hrp, dt, S)
    switchTimer = switchTimer + dt
    local interval = 1 / math.max(S.AntiAimSpeed, 1)
    if switchTimer >= interval then
        switchTimer  = 0
        jitterState  = not jitterState
    end
    local baseYaw      = jitterState and 180 or 0
    local jitterOffset = math.random(-45, 45)
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), math.rad(baseYaw + jitterOffset))
end

-- Face 90 degrees off from movement direction
ModeHandlers["SideWays"] = function(hrp, dt, S)
    local vel = hrp.AssemblyLinearVelocity
    if vel.Magnitude > 1 then
        local moveAngle = math.atan2(vel.X, vel.Z)
        ApplyRotation(hrp, math.rad(S.AntiAimPitch), moveAngle + math.rad(90))
    else
        ApplyRotation(hrp, math.rad(S.AntiAimPitch), math.rad(90))
    end
end

-- Always face 180 degrees from camera look direction
ModeHandlers["BackWards"] = function(hrp, dt, S)
    local camLook = Services.Camera.CFrame.LookVector
    local camYaw  = math.atan2(camLook.X, camLook.Z)
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), camYaw + math.pi)
end

-- Alternate between left 90 and right 90 relative to camera
ModeHandlers["HalfSideWays"] = function(hrp, dt, S)
    switchTimer = switchTimer + dt
    local interval = 1 / math.max(S.AntiAimSpeed * 0.5, 1)
    if switchTimer >= interval then
        switchTimer = 0
        jitterState = not jitterState
    end
    local camLook  = Services.Camera.CFrame.LookVector
    local camYaw   = math.atan2(camLook.X, camLook.Z)
    local offset   = jitterState and math.rad(90) or math.rad(-90)
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), camYaw + math.pi + offset)
end

-- Extreme downward pitch to break resolver
ModeHandlers["FakeDown"] = function(hrp, dt, S)
    angle = angle + (S.AntiAimSpeed * dt * 120)
    if angle > 360 then angle = angle - 360 end
    ApplyRotation(hrp, math.rad(89), math.rad(angle))
end

-- Extreme upward pitch
ModeHandlers["FakeUp"] = function(hrp, dt, S)
    angle = angle + (S.AntiAimSpeed * dt * 120)
    if angle > 360 then angle = angle - 360 end
    ApplyRotation(hrp, math.rad(-89), math.rad(angle))
end

-- Full random angles every 0.05s
ModeHandlers["Random"] = function(hrp, dt, S)
    switchTimer = switchTimer + dt
    if switchTimer >= 0.05 then
        switchTimer  = 0
        local randYaw   = math.rad(math.random(0, 360))
        local randPitch = math.rad(math.random(-89, 89))
        ApplyRotation(hrp, randPitch, randYaw)
    end
end

-- ==========================================
-- RESET LOCAL STATE
-- Called when AntiAim is disabled so next
-- enable starts fresh without leftover timers.
-- ==========================================
function AntiAim.Reset()
    angle       = 0
    jitterState = false
    switchTimer = 0
end

-- ==========================================
-- TICK
-- Called every frame from the render loop.
-- Exits immediately if conditions not met.
-- ==========================================
function AntiAim.Tick(dt)
    local S  = State.Settings
    local lp = Services.LocalPlayer

    if not S.AntiAimEnabled or not S.RageEnabled then
        return
    end

    local char = lp.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local handler = ModeHandlers[S.AntiAimMode]
    if handler then
        pcall(handler, hrp, dt, S)
    end
end

-- ==========================================
-- GET AVAILABLE MODES
-- Used by UI cycle button to populate options.
-- ==========================================
function AntiAim.GetModes()
    return {
        "Spin",
        "Jitter",
        "SideWays",
        "BackWards",
        "HalfSideWays",
        "FakeDown",
        "FakeUp",
        "Random",
    }
end

return AntiAim