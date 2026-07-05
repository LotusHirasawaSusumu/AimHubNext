-- engine/movement.lua
-- AimHubNext Movement Enhancement System
-- Features: Bhop, Air Strafe
-- Designed for CENTAURRA's jump cooldown/height limits
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local Movement = {}

-- ==========================================
-- SETTINGS BOOTSTRAP
-- Safely extends State.Settings without
-- overwriting values already loaded from
-- a saved config (hot-reload safe).
-- ==========================================
local MOVEMENT_DEFAULTS = {
    BhopEnabled       = false,
    AirStrafeEnabled  = false,
    BhopMode          = "Auto",
    AirStrafeStrength = 50,
    BhopAcceleration  = 50,
    BhopMaxSpeed      = 100,
    AirStrafeMode     = "Camera",
}

local function EnsureSettings()
    local S  = State.Settings
    local DS = State.DefaultSettings
    for key, value in pairs(MOVEMENT_DEFAULTS) do
        if S[key]  == nil then S[key]  = value end
        if DS[key] == nil then DS[key] = value end
    end
end

-- ==========================================
-- INTERNAL STATE
-- All mutable locals, reset on Cleanup().
-- ==========================================
local wasOnGround       = true
local jumpQueued        = false
local scrollJumpQueued  = false
local jumpCooldownTimer = 0
local scrollConn        = nil
local initDone          = false

-- CENTAURRA jump cooldown observed ~0.35s,
-- we use 0.40s to give server-side headroom.
local CENTAURRA_JUMP_COOLDOWN = 0.40

-- Hard cap on dt to prevent physics explosion
-- on lag spikes or first-frame anomalies.
local MAX_SAFE_DT = 0.05   -- 50ms = 20fps minimum

-- Hard cap on impulse magnitude per frame
-- regardless of settings values.
local MAX_IMPULSE_MAGNITUDE = 8.0

-- ==========================================
-- SAFE CHARACTER FETCH
-- Returns nil for ALL three values if ANY
-- component is missing or unhealthy.
-- Prevents partial-state race conditions.
-- ==========================================
local function GetCharacterState()
    local ok, char, hrp, hum = pcall(function()
        local lp   = Services.LocalPlayer
        local c    = lp.Character
        if not c then return nil, nil, nil end

        local h  = c:FindFirstChild("HumanoidRootPart")
        local hu = c:FindFirstChildOfClass("Humanoid")

        -- Validate all three exist and humanoid is alive
        if not h or not hu then return nil, nil, nil end
        if hu.Health <= 0   then return nil, nil, nil end

        -- Validate HRP is still in workspace hierarchy
        -- (catches mid-respawn destruction race)
        if not h:IsDescendantOf(workspace) then
            return nil, nil, nil
        end

        return c, h, hu
    end)

    if not ok then return nil, nil, nil end
    return char, hrp, hum
end

-- ==========================================
-- GROUND CHECK
-- Uses both FloorMaterial and a short
-- downward raycast as fallback.
-- FloorMaterial is deprecated but still
-- works on most executors; raycast is the
-- reliable backup.
-- ==========================================
local GroundRayParams = RaycastParams.new()
GroundRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsOnGround(char, hrp, hum)
    -- Primary: FloorMaterial (fast, no raycast cost)
    local floorMat = nil
    pcall(function()
        floorMat = hum.FloorMaterial
    end)
    if floorMat ~= nil then
        return floorMat ~= Enum.Material.Air
    end

    -- Fallback: short downward raycast
    local ok, result = pcall(function()
        GroundRayParams.FilterDescendantsInstances = { char }
        return workspace:Raycast(
            hrp.Position,
            Vector3.new(0, -3.5, 0),
            GroundRayParams
        )
    end)
    if not ok then return false end
    return result ~= nil
end

-- ==========================================
-- SAFE JUMP
-- Wraps hum.Jump assignment in pcall.
-- Also tries Humanoid:ChangeState as a
-- fallback for games that lock Jump property.
-- ==========================================
local function SafeJump(hum)
    local ok = false

    -- Method 1: Direct Jump property
    ok = pcall(function()
        hum.Jump = true
    end)

    -- Method 2: ChangeState fallback
    if not ok then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

-- ==========================================
-- GET STRAFE DIRECTION
-- Returns a safe Vector3 (never nan, never
-- zero-magnitude passed to .Unit).
-- ==========================================
local function GetStrafeDirection(hrp)
    local S      = State.Settings
    local Camera = Services.Camera
    local UIS    = Services.UserInputService

    -- Safe camera vector read
    local camLook  = Vector3.new(0, 0, -1)
    local camRight = Vector3.new(1, 0, 0)
    pcall(function()
        camLook  = Camera.CFrame.LookVector
        camRight = Camera.CFrame.RightVector
    end)

    -- Flatten to horizontal plane
    local flatLook  = Vector3.new(camLook.X,  0, camLook.Z)
    local flatRight = Vector3.new(camRight.X, 0, camRight.Z)

    -- Guard against zero-length flat vectors
    -- (happens when camera looks straight up/down)
    if flatLook.Magnitude  < 0.001 then flatLook  = Vector3.new(0, 0, -1) end
    if flatRight.Magnitude < 0.001 then flatRight = Vector3.new(1, 0, 0)  end

    local flatLookUnit  = flatLook.Unit
    local flatRightUnit = flatRight.Unit

    local mode    = S.AirStrafeMode
    local wasdDir = Vector3.new(0, 0, 0)

    -- Read WASD safely
    local wDown, sDown, aDown, dDown = false, false, false, false
    pcall(function()
        wDown = UIS:IsKeyDown(Enum.KeyCode.W)
        sDown = UIS:IsKeyDown(Enum.KeyCode.S)
        aDown = UIS:IsKeyDown(Enum.KeyCode.A)
        dDown = UIS:IsKeyDown(Enum.KeyCode.D)
    end)

    if wDown then wasdDir = wasdDir + flatLookUnit  end
    if sDown then wasdDir = wasdDir - flatLookUnit  end
    if aDown then wasdDir = wasdDir - flatRightUnit end
    if dDown then wasdDir = wasdDir + flatRightUnit end

    local result = Vector3.new(0, 0, 0)

    if mode == "Camera" then
        result = flatLookUnit

    elseif mode == "WASD" then
        if wasdDir.Magnitude > 0.001 then
            result = wasdDir
        else
            -- No input = no strafe force
            return nil
        end

    elseif mode == "Combined" then
        local blend = flatLookUnit + wasdDir
        if blend.Magnitude > 0.001 then
            result = blend
        else
            result = flatLookUnit
        end
    end

    -- Final magnitude check before .Unit
    if result.Magnitude < 0.001 then return nil end
    return result.Unit
end

-- ==========================================
-- BHOP HANDLER
-- ==========================================
local function HandleBhop(char, hrp, hum, onGround, currentTime, dt)
    local S   = State.Settings
    local UIS = Services.UserInputService

    -- Tick down cooldown
    jumpCooldownTimer = math.max(0, jumpCooldownTimer - dt)

    local mode = S.BhopMode

    if mode == "Auto" then
        -- Detect landing (was airborne, now grounded)
        if onGround and not wasOnGround then
            jumpQueued = true
        end
        if jumpQueued and onGround and jumpCooldownTimer <= 0 then
            SafeJump(hum)
            jumpQueued        = false
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end

    elseif mode == "Scroll" then
        if scrollJumpQueued and onGround and jumpCooldownTimer <= 0 then
            SafeJump(hum)
            scrollJumpQueued  = false
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end

    elseif mode == "Space" then
        local spaceHeld = false
        pcall(function()
            spaceHeld = UIS:IsKeyDown(Enum.KeyCode.Space)
        end)
        if spaceHeld and onGround and jumpCooldownTimer <= 0 then
            SafeJump(hum)
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end
    end
end

-- ==========================================
-- AIR STRAFE HANDLER
-- ==========================================
local function HandleAirStrafe(char, hrp, hum, onGround, dt)
    local S = State.Settings

    -- Only strafe while airborne
    if onGround then return end

    -- Get direction (nil = no input or unsafe)
    local strafeDir = GetStrafeDirection(hrp)
    if not strafeDir then return end

    -- Read current velocity safely
    local vel = Vector3.new(0, 0, 0)
    local velOk = pcall(function()
        vel = hrp.AssemblyLinearVelocity
    end)
    if not velOk then return end

    -- Horizontal component only
    local horizVel = Vector3.new(vel.X, 0, vel.Z)

    -- Settings -> safe numeric ranges
    local accel    = math.clamp(S.BhopAcceleration   / 100, 0.05, 1.0)
    local maxSpeed = math.clamp(S.BhopMaxSpeed,              10,   500)
    local strength = math.clamp(S.AirStrafeStrength  / 100, 0.01, 1.0)
                   * maxSpeed

    -- How much velocity we already have in strafe direction
    local proj = horizVel:Dot(strafeDir)

    -- Only push if below target speed in this direction
    if proj >= strength then return end

    -- dt is already clamped by caller, but clamp again defensively
    local safeDt = math.clamp(dt, 0.001, MAX_SAFE_DT)

    -- Compute raw impulse
    local rawImpulse = strafeDir * (strength - proj) * accel * safeDt * 20

    -- Guard: if magnitude is somehow nan or zero, abort
    local impMag = rawImpulse.Magnitude
    if impMag ~= impMag or impMag < 0.0001 then return end  -- nan check: nan ~= nan

    -- Clamp to per-frame maximum
    local clampedImpulse = rawImpulse
    if impMag > MAX_IMPULSE_MAGNITUDE then
        clampedImpulse = rawImpulse.Unit * MAX_IMPULSE_MAGNITUDE
    end

    -- Get mass safely
    local mass = 1.0
    pcall(function()
        local m = hrp.AssemblyMass
        if m and m == m and m > 0 then  -- nan check + positive check
            mass = m
        end
    end)

    -- Apply horizontal impulse only (Y = 0 always)
    pcall(function()
        hrp:ApplyImpulse(
            Vector3.new(
                clampedImpulse.X * mass,
                0,
                clampedImpulse.Z * mass
            )
        )
    end)
end

-- ==========================================
-- TICK
-- Called from render loop every frame.
-- dt is sanitized here before passing down.
-- ==========================================
function Movement.Tick(dt)
    local S = State.Settings

    -- Quick exit if both features off
    if not S.BhopEnabled and not S.AirStrafeEnabled then
        return
    end

    -- Sanitize dt: cap spike frames, floor tiny frames
    local safeDt = math.clamp(dt or 0.016, 0.001, MAX_SAFE_DT)

    -- Fetch character state once, share between handlers
    local char, hrp, hum = GetCharacterState()
    if not char then
        -- Reset ground state so bhop doesn't
        -- misfire on the next valid frame
        wasOnGround = true
        return
    end

    -- Ground check once per frame, shared by both handlers
    local onGround = false
    pcall(function()
        onGround = IsOnGround(char, hrp, hum)
    end)

    local currentTime = tick()

    if S.BhopEnabled then
        pcall(HandleBhop, char, hrp, hum, onGround, currentTime, safeDt)
    end

    if S.AirStrafeEnabled then
        pcall(HandleAirStrafe, char, hrp, hum, onGround, safeDt)
    end

    -- Update ground state AFTER both handlers read it
    wasOnGround = onGround
end

-- ==========================================
-- INIT
-- Safe to call multiple times (hot-reload).
-- ==========================================
function Movement.Init()
    if initDone then
        -- Already initialized, just re-ensure settings
        EnsureSettings()
        return
    end

    EnsureSettings()

    -- Scroll wheel listener
    -- Guard: only register if not already connected
    if not scrollConn then
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

    initDone = true
end

-- ==========================================
-- CLEANUP
-- Resets all state, disconnects listeners.
-- ==========================================
function Movement.Cleanup()
    wasOnGround       = true
    jumpQueued        = false
    scrollJumpQueued  = false
    jumpCooldownTimer = 0
    initDone          = false

    if scrollConn then
        pcall(function() scrollConn:Disconnect() end)
        scrollConn = nil
    end
end

-- ==========================================
-- MODE LISTS (for UI dropdowns)
-- ==========================================
function Movement.GetBhopModes()
    return { "Auto", "Scroll", "Space" }
end

function Movement.GetStrafeModes()
    return { "Camera", "WASD", "Combined" }
end

return Movement