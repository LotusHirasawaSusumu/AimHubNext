-- engine/movement.lua
-- AimHubNext Movement Enhancement System
-- Features: Bhop, Air Strafe, No-Cooldown Experimental Bhop
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local Movement = {}

-- ==========================================
-- SETTINGS BOOTSTRAP
-- ==========================================
local MOVEMENT_DEFAULTS = {
    BhopEnabled           = false,
    AirStrafeEnabled      = false,
    BhopMode              = "Auto",
    AirStrafeStrength     = 50,
    BhopAcceleration      = 50,
    BhopMaxSpeed          = 100,
    AirStrafeMode         = "Camera",
    -- NEW: experimental no-cooldown bhop
    BhopNoCooldown        = false,
    BhopNoCooldownMethod  = "StateSkip",  -- "StateSkip" | "VelocityInject"
    BhopJumpPower         = 50,           -- velocity inject power (studs/s)
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
-- ==========================================
local wasOnGround           = true
local jumpQueued            = false
local scrollJumpQueued      = false
local jumpCooldownTimer     = 0
local scrollConn            = nil
local initDone              = false
local lastVelocityY         = 0     -- tracks Y velocity for pre-land detection
local stateSkipActive       = false -- whether we're in a state-skip cycle
local stateSkipConn         = nil   -- humanoid state changed connection

-- Safety constants
local CENTAURRA_JUMP_COOLDOWN  = 0.40
local MAX_SAFE_DT              = 0.05
local MAX_IMPULSE_MAGNITUDE    = 8.0

-- Velocity inject: inject upward velocity when
-- Y velocity crosses this threshold (falling, near ground)
-- Negative = falling downward
local PRELAND_VELOCITY_THRESHOLD = -2.0

-- ==========================================
-- SAFE CHARACTER FETCH
-- ==========================================
local function GetCharacterState()
    local ok, char, hrp, hum = pcall(function()
        local lp = Services.LocalPlayer
        local c  = lp.Character
        if not c then return nil, nil, nil end
        local h  = c:FindFirstChild("HumanoidRootPart")
        local hu = c:FindFirstChildOfClass("Humanoid")
        if not h or not hu then return nil, nil, nil end
        if hu.Health <= 0 then return nil, nil, nil end
        if not h:IsDescendantOf(workspace) then return nil, nil, nil end
        return c, h, hu
    end)
    if not ok then return nil, nil, nil end
    return char, hrp, hum
end

-- ==========================================
-- GROUND CHECK
-- ==========================================
local GroundRayParams = RaycastParams.new()
GroundRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsOnGround(char, hrp, hum)
    local floorMat = nil
    pcall(function() floorMat = hum.FloorMaterial end)
    if floorMat ~= nil then
        return floorMat ~= Enum.Material.Air
    end
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
-- ==========================================
local function SafeJump(hum)
    local ok = pcall(function() hum.Jump = true end)
    if not ok then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

-- ==========================================
-- NO-COOLDOWN METHOD 1: STATE SKIP
--
-- How it works:
-- Humanoid's state machine goes:
--   Jumping → Freefall → Landed → GettingUp → Running
-- The delay is in GettingUp → Running transition.
-- We force-disable GettingUp state so the machine
-- skips directly from Landed → Running → can jump again.
--
-- SetStateEnabled(GettingUp, false) is the key call.
-- We re-enable it after one frame so it doesn't
-- permanently break the character.
-- ==========================================
local function ApplyStateSkip(hum)
    pcall(function()
        -- Disable the GettingUp state to skip cooldown
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

        -- Force transition to Running so jump is available
        hum:ChangeState(Enum.HumanoidStateType.Running)

        -- Re-enable GettingUp after 1 frame
        -- so normal animations still work when not bhoping
        task.defer(function()
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            end)
        end)
    end)
end

-- ==========================================
-- NO-COOLDOWN METHOD 2: VELOCITY INJECT
--
-- How it works:
-- Instead of fighting the state machine,
-- we detect the frame where Y velocity goes
-- from negative (falling) toward zero (landing).
-- At that exact moment we inject upward velocity
-- to prevent the Landed state from ever triggering.
-- The player never technically "lands" so there
-- is no cooldown at all.
--
-- This is conceptually identical to how
-- Source engine bhop works: the jump is queued
-- and fires before the ground state registers.
-- ==========================================
local function ApplyVelocityInject(hrp, hum)
    local power = math.clamp(State.Settings.BhopJumpPower, 10, 200)

    pcall(function()
        -- Get current Y velocity
        local vel = hrp.AssemblyLinearVelocity

        -- Safety: nan check
        if vel ~= vel then return end

        -- Only inject when falling (negative Y) and near ground
        if vel.Y > PRELAND_VELOCITY_THRESHOLD then return end

        local mass = 1.0
        pcall(function()
            local m = hrp.AssemblyMass
            if m and m == m and m > 0 then mass = m end
        end)

        -- Cancel downward velocity and inject upward impulse
        -- We zero out Y velocity first via VectorForce-style impulse
        -- then add jump power
        local cancelDownward = Vector3.new(0, -vel.Y * mass, 0)
        local jumpImpulse    = Vector3.new(0, power * mass, 0)

        hrp:ApplyImpulse(cancelDownward + jumpImpulse)
    end)
end

-- ==========================================
-- NO-COOLDOWN DISPATCHER
-- Picks method based on setting.
-- Called when landing is detected.
-- ==========================================
local function ApplyNoCooldown(char, hrp, hum, onGround, dt)
    local S = State.Settings
    if not S.BhopNoCooldown then return false end

    local method = S.BhopNoCooldownMethod

    if method == "StateSkip" then
        -- Apply on landing frame
        if onGround and not wasOnGround then
            ApplyStateSkip(hum)
            -- Immediately queue jump after state skip
            task.defer(function()
                pcall(function()
                    if hum and hum.Health > 0 then
                        hum.Jump = true
                    end
                end)
            end)
            return true
        end

    elseif method == "VelocityInject" then
        -- Apply continuously while falling near ground
        -- (pre-land injection)
        if not onGround then
            local vel = Vector3.new(0, 0, 0)
            pcall(function() vel = hrp.AssemblyLinearVelocity end)

            -- Detect falling toward ground
            if vel.Y < PRELAND_VELOCITY_THRESHOLD then
                -- Check if ground is close (within 3 studs)
                local groundClose = false
                pcall(function()
                    GroundRayParams.FilterDescendantsInstances = { char }
                    local result = workspace:Raycast(
                        hrp.Position,
                        Vector3.new(0, -3.0, 0),
                        GroundRayParams
                    )
                    groundClose = result ~= nil
                end)

                if groundClose then
                    ApplyVelocityInject(hrp, hum)
                    return true
                end
            end
        end
    end

    return false
end

-- ==========================================
-- STANDARD BHOP HANDLER
-- Only runs when NoCooldown is OFF.
-- ==========================================
local function HandleBhop(char, hrp, hum, onGround, currentTime, dt)
    local S   = State.Settings
    local UIS = Services.UserInputService

    jumpCooldownTimer = math.max(0, jumpCooldownTimer - dt)

    local mode = S.BhopMode

    if mode == "Auto" then
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
local function GetStrafeDirection(hrp)
    local S      = State.Settings
    local Camera = Services.Camera
    local UIS    = Services.UserInputService

    local camLook  = Vector3.new(0, 0, -1)
    local camRight = Vector3.new(1, 0, 0)
    pcall(function()
        camLook  = Camera.CFrame.LookVector
        camRight = Camera.CFrame.RightVector
    end)

    local flatLook  = Vector3.new(camLook.X,  0, camLook.Z)
    local flatRight = Vector3.new(camRight.X, 0, camRight.Z)

    if flatLook.Magnitude  < 0.001 then flatLook  = Vector3.new(0, 0, -1) end
    if flatRight.Magnitude < 0.001 then flatRight = Vector3.new(1, 0, 0)  end

    local flatLookUnit  = flatLook.Unit
    local flatRightUnit = flatRight.Unit

    local wDown, sDown, aDown, dDown = false, false, false, false
    pcall(function()
        wDown = UIS:IsKeyDown(Enum.KeyCode.W)
        sDown = UIS:IsKeyDown(Enum.KeyCode.S)
        aDown = UIS:IsKeyDown(Enum.KeyCode.A)
        dDown = UIS:IsKeyDown(Enum.KeyCode.D)
    end)

    local wasdDir = Vector3.new(0, 0, 0)
    if wDown then wasdDir = wasdDir + flatLookUnit  end
    if sDown then wasdDir = wasdDir - flatLookUnit  end
    if aDown then wasdDir = wasdDir - flatRightUnit end
    if dDown then wasdDir = wasdDir + flatRightUnit end

    local result = Vector3.new(0, 0, 0)
    local mode   = S.AirStrafeMode

    if mode == "Camera" then
        result = flatLookUnit
    elseif mode == "WASD" then
        if wasdDir.Magnitude > 0.001 then result = wasdDir
        else return nil end
    elseif mode == "Combined" then
        local blend = flatLookUnit + wasdDir
        result = blend.Magnitude > 0.001 and blend or flatLookUnit
    end

    if result.Magnitude < 0.001 then return nil end
    return result.Unit
end

local function HandleAirStrafe(char, hrp, hum, onGround, dt)
    if onGround then return end

    local strafeDir = GetStrafeDirection(hrp)
    if not strafeDir then return end

    local vel = Vector3.new(0, 0, 0)
    if not pcall(function() vel = hrp.AssemblyLinearVelocity end) then
        return
    end

    local S        = State.Settings
    local accel    = math.clamp(S.BhopAcceleration  / 100, 0.05, 1.0)
    local maxSpeed = math.clamp(S.BhopMaxSpeed,             10,   500)
    local strength = math.clamp(S.AirStrafeStrength / 100, 0.01, 1.0)
                   * maxSpeed

    local horizVel = Vector3.new(vel.X, 0, vel.Z)
    local proj     = horizVel:Dot(strafeDir)
    if proj >= strength then return end

    local safeDt     = math.clamp(dt, 0.001, MAX_SAFE_DT)
    local rawImpulse = strafeDir * (strength - proj) * accel * safeDt * 20

    local impMag = rawImpulse.Magnitude
    if impMag ~= impMag or impMag < 0.0001 then return end

    local clampedImpulse = impMag > MAX_IMPULSE_MAGNITUDE
        and rawImpulse.Unit * MAX_IMPULSE_MAGNITUDE
        or  rawImpulse

    local mass = 1.0
    pcall(function()
        local m = hrp.AssemblyMass
        if m and m == m and m > 0 then mass = m end
    end)

    pcall(function()
        hrp:ApplyImpulse(Vector3.new(
            clampedImpulse.X * mass,
            0,
            clampedImpulse.Z * mass
        ))
    end)
end

-- ==========================================
-- TICK
-- ==========================================
function Movement.Tick(dt)
    local S = State.Settings
    if not S.BhopEnabled and not S.AirStrafeEnabled then return end

    local safeDt = math.clamp(dt or 0.016, 0.001, MAX_SAFE_DT)

    local char, hrp, hum = GetCharacterState()
    if not char then
        wasOnGround = true
        return
    end

    local onGround = false
    pcall(function() onGround = IsOnGround(char, hrp, hum) end)

    local currentTime = tick()

    if S.BhopEnabled then
        -- Try no-cooldown first if enabled
        -- If it handles the jump, skip standard bhop this frame
        local noCooldownHandled = false
        if S.BhopNoCooldown then
            pcall(function()
                noCooldownHandled = ApplyNoCooldown(
                    char, hrp, hum, onGround, safeDt
                )
            end)
        end

        -- Standard bhop as fallback or when NoCooldown is off
        if not noCooldownHandled then
            pcall(HandleBhop, char, hrp, hum, onGround, currentTime, safeDt)
        end
    end

    if S.AirStrafeEnabled then
        pcall(HandleAirStrafe, char, hrp, hum, onGround, safeDt)
    end

    wasOnGround = onGround
end

-- ==========================================
-- INIT
-- ==========================================
function Movement.Init()
    if initDone then
        EnsureSettings()
        return
    end
    EnsureSettings()
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
    -- Re-enable GettingUp in case we left it disabled
    pcall(function()
        local char = Services.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
        end
    end)
end

function Movement.GetBhopModes()
    return { "Auto", "Scroll", "Space" }
end

function Movement.GetStrafeModes()
    return { "Camera", "WASD", "Combined" }
end

function Movement.GetNoCooldownMethods()
    return { "StateSkip", "VelocityInject" }
end

return Movement