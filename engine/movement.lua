-- engine/movement.lua
-- AimHubNext Movement Enhancement System
-- Features: Bhop (auto-jump on land), Air Strafe
-- Designed for CENTAURRA's jump cooldown/height limits
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Utils    = require("core/utils.lua")

local Movement = {}

-- ==========================================
-- MOVEMENT SETTINGS
-- Added into State.Settings by this module.
-- We extend the settings table directly.
-- ==========================================
local function EnsureSettings()
    local S = State.Settings
    if S.BhopEnabled          == nil then S.BhopEnabled          = false end
    if S.AirStrafeEnabled     == nil then S.AirStrafeEnabled     = false end
    if S.BhopMode             == nil then S.BhopMode             = "Auto" end
    if S.AirStrafeStrength    == nil then S.AirStrafeStrength    = 50 end
    if S.BhopAcceleration     == nil then S.BhopAcceleration     = 50 end
    if S.BhopMaxSpeed         == nil then S.BhopMaxSpeed         = 100 end
    if S.AirStrafeMode        == nil then S.AirStrafeMode        = "Camera" end

    -- Mirror new keys into DefaultSettings
    local DS = State.DefaultSettings
    if DS.BhopEnabled          == nil then DS.BhopEnabled          = false end
    if DS.AirStrafeEnabled     == nil then DS.AirStrafeEnabled     = false end
    if DS.BhopMode             == nil then DS.BhopMode             = "Auto" end
    if DS.AirStrafeStrength    == nil then DS.AirStrafeStrength    = 50 end
    if DS.BhopAcceleration     == nil then DS.BhopAcceleration     = 50 end
    if DS.BhopMaxSpeed         == nil then DS.BhopMaxSpeed         = 100 end
    if DS.AirStrafeMode        == nil then DS.AirStrafeMode        = "Camera" end
end

-- ==========================================
-- INTERNAL STATE
-- ==========================================
local wasOnGround       = true
local jumpQueued        = false
local lastJumpTime      = 0
local airStrafeActive   = false
local jumpCooldownTimer = 0

-- CENTAURRA specific:
-- Jump cooldown is approximately 0.35s based on testing.
-- We wait slightly longer (0.38s) to avoid server rejection.
local CENTAURRA_JUMP_COOLDOWN = 0.38

-- ==========================================
-- HELPERS
-- ==========================================
local function GetCharacterState()
    local lp   = Services.LocalPlayer
    local char = lp.Character
    if not char then return nil, nil, nil end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return nil, nil, nil end

    return char, hrp, hum
end

local function IsOnGround(hum)
    return hum.FloorMaterial ~= Enum.Material.Air
end

-- ==========================================
-- GET STRAFE DIRECTION
-- Returns a unit Vector3 for air strafe
-- based on current mode setting.
--
-- "Camera"  = strafe toward camera look direction
-- "WASD"    = strafe based on keyboard input
-- "Combined"= blend of both
-- ==========================================
local function GetStrafeDirection(hrp, hum)
    local S      = State.Settings
    local Camera = Services.Camera
    local UIS    = Services.UserInputService

    local camLook = Camera.CFrame.LookVector
    local camRight= Camera.CFrame.RightVector

    -- Read WASD input
    local wasdDir = Vector3.new(0, 0, 0)
    local wDown = UIS:IsKeyDown(Enum.KeyCode.W)
    local sDown = UIS:IsKeyDown(Enum.KeyCode.S)
    local aDown = UIS:IsKeyDown(Enum.KeyCode.A)
    local dDown = UIS:IsKeyDown(Enum.KeyCode.D)

    if wDown then wasdDir = wasdDir + Vector3.new(camLook.X, 0, camLook.Z) end
    if sDown then wasdDir = wasdDir - Vector3.new(camLook.X, 0, camLook.Z) end
    if aDown then wasdDir = wasdDir - Vector3.new(camRight.X, 0, camRight.Z) end
    if dDown then wasdDir = wasdDir + Vector3.new(camRight.X, 0, camRight.Z) end

    if S.AirStrafeMode == "Camera" then
        -- Pure camera forward
        return Vector3.new(camLook.X, 0, camLook.Z).Unit

    elseif S.AirStrafeMode == "WASD" then
        -- Pure WASD
        if wasdDir.Magnitude > 0.01 then
            return wasdDir.Unit
        end
        return Vector3.new(0, 0, 0)

    elseif S.AirStrafeMode == "Combined" then
        -- Blend camera + WASD 50/50
        local camDir = Vector3.new(camLook.X, 0, camLook.Z)
        local blend  = camDir + wasdDir
        if blend.Magnitude > 0.01 then
            return blend.Unit
        end
        return camDir.Unit
    end

    return Vector3.new(0, 0, 0)
end

-- ==========================================
-- BHOP LOGIC
-- Modes:
--   "Auto"   = jump automatically the instant
--              character lands (true bhop)
--   "Scroll" = jump on scroll wheel input
--              (classic bhop input method)
--   "Space"  = jump on spacebar hold,
--              timed to minimize cooldown
-- ==========================================
local scrollJumpQueued = false

local function HandleBhop(char, hrp, hum, currentTime, dt)
    local S       = State.Settings
    local UIS     = Services.UserInputService
    local onGround= IsOnGround(hum)

    -- Jump cooldown tracking
    jumpCooldownTimer = math.max(0, jumpCooldownTimer - dt)

    if S.BhopMode == "Auto" then
        -- Queue a jump the moment we detect landing
        if onGround and not wasOnGround then
            jumpQueued = true
        end

        if jumpQueued and onGround and jumpCooldownTimer <= 0 then
            pcall(function()
                hum.Jump = true
            end)
            jumpQueued        = false
            lastJumpTime      = currentTime
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end

    elseif S.BhopMode == "Scroll" then
        -- scrollJumpQueued is set by input connection
        if scrollJumpQueued and onGround and jumpCooldownTimer <= 0 then
            pcall(function()
                hum.Jump = true
            end)
            scrollJumpQueued  = false
            lastJumpTime      = currentTime
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end

    elseif S.BhopMode == "Space" then
        -- Hold space, we time the jump to land as soon
        -- as cooldown expires after touching ground
        local spaceHeld = UIS:IsKeyDown(Enum.KeyCode.Space)
        if spaceHeld and onGround and jumpCooldownTimer <= 0 then
            pcall(function()
                hum.Jump = true
            end)
            lastJumpTime      = currentTime
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end
    end

    wasOnGround = onGround
end

-- ==========================================
-- AIR STRAFE LOGIC
-- Applies velocity impulse in strafe
-- direction while airborne.
-- Strength and acceleration are user-tunable.
-- ==========================================
local function HandleAirStrafe(char, hrp, hum, dt)
    local S       = State.Settings
    local UIS     = Services.UserInputService
    local onGround= IsOnGround(hum)

    -- Only strafe while airborne
    if onGround then
        airStrafeActive = false
        return
    end

    airStrafeActive = true

    local strafeDir = GetStrafeDirection(hrp, hum)
    if strafeDir.Magnitude < 0.01 then return end

    -- Acceleration scales from 0.1 to 1.0
    local accel     = math.clamp(S.BhopAcceleration / 100, 0.05, 1.0)
    -- Strength scales from 0 to max speed
    local maxSpeed  = math.clamp(S.BhopMaxSpeed, 10, 500)
    local strength  = math.clamp(S.AirStrafeStrength / 100, 0.01, 1.0)
                    * maxSpeed

    -- Current horizontal velocity
    local vel       = hrp.AssemblyLinearVelocity
    local horizVel  = Vector3.new(vel.X, 0, vel.Z)

    -- Project current velocity onto strafe direction
    local proj      = horizVel:Dot(strafeDir)

    -- Only add velocity if we haven't exceeded max in that direction
    if proj < strength then
        local impulse = strafeDir * (strength - proj) * accel * dt * 60
        -- Cap impulse magnitude per frame to avoid physics explosion
        local maxImpulse = strength * 0.15
        if impulse.Magnitude > maxImpulse then
            impulse = impulse.Unit * maxImpulse
        end

        pcall(function()
            hrp:ApplyImpulse(
                Vector3.new(impulse.X, 0, impulse.Z)
                * hrp.AssemblyMass
            )
        end)
    end
end

-- ==========================================
-- SCROLL WHEEL INPUT WATCHER
-- Registered once on Init, always listening.
-- Only acts when Bhop Scroll mode is active.
-- ==========================================
local scrollConn = nil

local function StartScrollListener()
    if scrollConn then return end
    local UIS = Services.UserInputService
    scrollConn = UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if not State.Settings.BhopEnabled then return end
        if State.Settings.BhopMode ~= "Scroll" then return end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            scrollJumpQueued = true
        end
    end)
    table.insert(State.GlobalConnections, scrollConn)
end

-- ==========================================
-- TICK
-- Called from the render loop every frame.
-- ==========================================
function Movement.Tick(dt)
    local S = State.Settings

    local bhopActive   = S.BhopEnabled
    local strafeActive = S.AirStrafeEnabled

    if not bhopActive and not strafeActive then return end

    local currentTime = tick()
    local char, hrp, hum = GetCharacterState()
    if not char then return end

    if bhopActive then
        pcall(HandleBhop, char, hrp, hum, currentTime, dt)
    end

    if strafeActive then
        pcall(HandleAirStrafe, char, hrp, hum, dt)
    end
end

-- ==========================================
-- INIT
-- Called from main.lua after module load.
-- ==========================================
function Movement.Init()
    EnsureSettings()
    StartScrollListener()
end

-- ==========================================
-- CLEANUP
-- ==========================================
function Movement.Cleanup()
    wasOnGround       = true
    jumpQueued        = false
    scrollJumpQueued  = false
    jumpCooldownTimer = 0
    airStrafeActive   = false
    if scrollConn then
        pcall(function() scrollConn:Disconnect() end)
        scrollConn = nil
    end
end

-- ==========================================
-- GET BHOP MODES (for UI dropdown)
-- ==========================================
function Movement.GetBhopModes()
    return { "Auto", "Scroll", "Space" }
end

-- ==========================================
-- GET STRAFE MODES (for UI dropdown)
-- ==========================================
function Movement.GetStrafeModes()
    return { "Camera", "WASD", "Combined" }
end

return Movement