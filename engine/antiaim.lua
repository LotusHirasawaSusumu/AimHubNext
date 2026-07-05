-- engine/antiaim.lua
-- AimHubNext Anti-Aim System
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local AntiAim = {}

local angle       = 0
local jitterState = false
local switchTimer = 0

local function ApplyRotation(hrp, pitchRad, yawRad)
    local pos = hrp.Position
    hrp.CFrame = CFrame.new(pos) * CFrame.Angles(pitchRad, yawRad, 0)
end

local ModeHandlers = {}

ModeHandlers["Spin"] = function(hrp, dt, S)
    angle = (angle + S.AntiAimSpeed * dt * 360) % 360
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), math.rad(angle))
end

ModeHandlers["Jitter"] = function(hrp, dt, S)
    switchTimer = switchTimer + dt
    if switchTimer >= 1 / math.max(S.AntiAimSpeed, 1) then
        switchTimer = 0
        jitterState = not jitterState
    end
    ApplyRotation(hrp,
        math.rad(S.AntiAimPitch),
        math.rad((jitterState and 180 or 0) + math.random(-45, 45))
    )
end

ModeHandlers["SideWays"] = function(hrp, dt, S)
    local vel = hrp.AssemblyLinearVelocity
    local yaw = vel.Magnitude > 1
        and math.atan2(vel.X, vel.Z) + math.rad(90)
        or  math.rad(90)
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), yaw)
end

ModeHandlers["BackWards"] = function(hrp, dt, S)
    local look = Services.Camera.CFrame.LookVector
    ApplyRotation(hrp,
        math.rad(S.AntiAimPitch),
        math.atan2(look.X, look.Z) + math.pi
    )
end

ModeHandlers["HalfSideWays"] = function(hrp, dt, S)
    switchTimer = switchTimer + dt
    if switchTimer >= 1 / math.max(S.AntiAimSpeed * 0.5, 1) then
        switchTimer = 0
        jitterState = not jitterState
    end
    local look   = Services.Camera.CFrame.LookVector
    local camYaw = math.atan2(look.X, look.Z)
    local offset = jitterState and math.rad(90) or math.rad(-90)
    ApplyRotation(hrp, math.rad(S.AntiAimPitch), camYaw + math.pi + offset)
end

ModeHandlers["FakeDown"] = function(hrp, dt, S)
    angle = (angle + S.AntiAimSpeed * dt * 120) % 360
    ApplyRotation(hrp, math.rad(89), math.rad(angle))
end

ModeHandlers["FakeUp"] = function(hrp, dt, S)
    angle = (angle + S.AntiAimSpeed * dt * 120) % 360
    ApplyRotation(hrp, math.rad(-89), math.rad(angle))
end

ModeHandlers["Random"] = function(hrp, dt, S)
    switchTimer = switchTimer + dt
    if switchTimer >= 0.05 then
        switchTimer = 0
        ApplyRotation(hrp,
            math.rad(math.random(-89, 89)),
            math.rad(math.random(0, 360))
        )
    end
end

function AntiAim.Reset()
    angle       = 0
    jitterState = false
    switchTimer = 0
end

function AntiAim.Tick(dt)
    local S  = State.Settings
    local lp = Services.LocalPlayer
    if not S.AntiAimEnabled or not S.RageEnabled then return end
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local handler = ModeHandlers[S.AntiAimMode]
    if handler then pcall(handler, hrp, dt, S) end
end

function AntiAim.GetModes()
    return {
        "Spin","Jitter","SideWays","BackWards",
        "HalfSideWays","FakeDown","FakeUp","Random"
    }
end

return AntiAim