-- engine/movement.lua
-- AimHubNext Movement Enhancement System
-- Multi-game: CENTAURRA, Bloxstrike, Generic
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
    BhopNoCooldown        = false,
    BhopNoCooldownMethod  = "StateSkip",
    BhopJumpPower         = 50,
    -- NEW: game profile
    MovementProfile       = "Generic",  -- "Generic" | "Bloxstrike" | "CENTAURRA"
    BloxstrikeSpeedCap    = 85,         -- Bloxstrike horizontal speed cap (studs/s)
    BloxstrikeStrafePower = 8,          -- Bloxstrike strafe boost per frame
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
local wasOnGround       = true
local jumpQueued        = false
local scrollJumpQueued  = false
local jumpCooldownTimer = 0
local scrollConn        = nil
local initDone          = false

local CENTAURRA_JUMP_COOLDOWN = 0.40
local MAX_SAFE_DT             = 0.05
local MAX_IMPULSE_MAGNITUDE   = 8.0
local PRELAND_VEL_THRESHOLD   = -2.0

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
-- NO-COOLDOWN METHODS (CENTAURRA / Generic)
-- ==========================================
local function ApplyStateSkip(hum)
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        hum:ChangeState(Enum.HumanoidStateType.Running)
        task.defer(function()
            pcall(function()
                hum:SetStateEnabled(
                    Enum.HumanoidStateType.GettingUp, true
                )
            end)
        end)
    end)
end

local function ApplyVelocityInject(hrp, hum, char)
    local power = math.clamp(State.Settings.BhopJumpPower, 10, 200)
    pcall(function()
        local vel = hrp.AssemblyLinearVelocity
        if vel ~= vel then return end
        if vel.Y > PRELAND_VEL_THRESHOLD then return end
        local mass = 1.0
        pcall(function()
            local m = hrp.AssemblyMass
            if m and m == m and m > 0 then mass = m end
        end)
        local cancelDown  = Vector3.new(0, -vel.Y * mass, 0)
        local jumpImpulse = Vector3.new(0, power * mass, 0)
        hrp:ApplyImpulse(cancelDown + jumpImpulse)
    end)
end

local function ApplyNoCooldown(char, hrp, hum, onGround)
    local S      = State.Settings
    local method = S.BhopNoCooldownMethod

    if method == "StateSkip" then
        if onGround and not wasOnGround then
            ApplyStateSkip(hum)
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
        if not onGround then
            local vel = Vector3.new(0, 0, 0)
            pcall(function() vel = hrp.AssemblyLinearVelocity end)
            if vel.Y < PRELAND_VEL_THRESHOLD then
                local groundClose = false
                pcall(function()
                    GroundRayParams.FilterDescendantsInstances = { char }
                    local r = workspace:Raycast(
                        hrp.Position,
                        Vector3.new(0, -3.0, 0),
                        GroundRayParams
                    )
                    groundClose = r ~= nil
                end)
                if groundClose then
                    ApplyVelocityInject(hrp, hum, char)
                    return true
                end
            end
        end
    end
    return false
end

-- ==========================================
-- GENERIC BHOP HANDLER
-- ==========================================
local function HandleGenericBhop(char, hrp, hum, onGround, currentTime, dt)
    local S   = State.Settings
    local UIS = Services.UserInputService

    jumpCooldownTimer = math.max(0, jumpCooldownTimer - dt)
    local mode = S.BhopMode

    if mode == "Auto" then
        if onGround and not wasOnGround then jumpQueued = true end
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
        pcall(function() spaceHeld = UIS:IsKeyDown(Enum.KeyCode.Space) end)
        if spaceHeld and onGround and jumpCooldownTimer <= 0 then
            SafeJump(hum)
            jumpCooldownTimer = CENTAURRA_JUMP_COOLDOWN
        end
    end
end

-- ==========================================
-- BLOXSTRIKE BHOP HANDLER
-- Mirrors the reference implementation exactly.
-- Space held + on ground = jump immediately,
-- no cooldown tracking needed because Bloxstrike
-- doesn't gate hum.Jump the same way.
-- ==========================================
local function HandleBloxstrikeBhop(char, hrp, hum, onGround)
    local UIS = Services.UserInputService
    local S   = State.Settings

    local spaceHeld = false
    pcall(function()
        spaceHeld = UIS:IsKeyDown(Enum.KeyCode.Space)
    end)

    if not spaceHeld then return end

    if onGround then
        -- On ground: just jump
        pcall(function() hum.Jump = true end)

    else
        -- Airborne + space held: air strafe if moving
        if not S.AirStrafeEnabled then return end

        local moveDir = Vector3.new(0, 0, 0)
        pcall(function() moveDir = hum.MoveDirection end)

        -- Only strafe if player has movement input
        if moveDir.Magnitude <= 0.01 then return end

        local currentVel = Vector3.new(0, 0, 0)
        pcall(function()
            currentVel = hrp.AssemblyLinearVelocity
        end)

        -- nan safety
        if currentVel ~= currentVel then return end

        local strafePower = math.clamp(S.BloxstrikeStrafePower, 1, 50)
        local boost       = moveDir * strafePower
        local speedCap    = math.clamp(S.BloxstrikeSpeedCap, 20, 300)

        local newVel = Vector3.new(
            currentVel.X + boost.X,
            currentVel.Y,           -- preserve vertical, never touch Y
            currentVel.Z + boost.Z
        )

        -- Horizontal speed cap
        local horizMag = Vector3.new(newVel.X, 0, newVel.Z).Magnitude
        if horizMag > speedCap then
            -- nan safety before .Unit
            if horizMag > 0.001 then
                local horizUnit = Vector3.new(
                    newVel.X, 0, newVel.Z
                ).Unit
                newVel = Vector3.new(
                    horizUnit.X * speedCap,
                    newVel.Y,
                    horizUnit.Z * speedCap
                )
            end
        end

        pcall(function()
            hrp.AssemblyLinearVelocity = newVel
        end)
    end
end

-- ==========================================
-- GENERIC AIR STRAFE HANDLER
-- (Unchanged from previous version, kept for
--  Generic and CENTAURRA profiles)
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

    local mode   = S.AirStrafeMode
    local result = Vector3.new(0, 0, 0)

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

local function HandleGenericAirStrafe(char, hrp, hum, onGround, dt)
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
-- Routes to correct profile handlers.
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
    local profile     = S.MovementProfile or "Generic"

    -- ---- BLOXSTRIKE PROFILE ----
    if profile == "Bloxstrike" then
        -- Bloxstrike bhop handles its own air strafe internally
        -- when space is held airborne, so we only call one handler
        if S.BhopEnabled then
            pcall(HandleBloxstrikeBhop, char, hrp, hum, onGround)
        end

        -- Generic air strafe still available separately
        -- for non-space-held strafe in Bloxstrike
        if S.AirStrafeEnabled then
            pcall(HandleGenericAirStrafe,
                char, hrp, hum, onGround, safeDt
            )
        end

    -- ---- CENTAURRA / GENERIC PROFILE ----
    else
        if S.BhopEnabled then
            local noCooldownHandled = false
            if S.BhopNoCooldown then
                pcall(function()
                    noCooldownHandled = ApplyNoCooldown(
                        char, hrp, hum, onGround
                    )
                end)
            end
            if not noCooldownHandled then
                pcall(HandleGenericBhop,
                    char, hrp, hum, onGround, currentTime, safeDt
                )
            end
        end

        if S.AirStrafeEnabled then
            pcall(HandleGenericAirStrafe,
                char, hrp, hum, onGround, safeDt
            )
        end
    end

    wasOnGround = onGround
end

-- ==========================================
-- INIT / CLEANUP / MODE LISTS
-- ==========================================
function Movement.Init()
    if initDone then EnsureSettings() return end
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

function Movement.GetProfiles()
    return { "Generic", "Bloxstrike", "CENTAURRA" }
end

return Movement