-- engine/movement.lua
-- AimHubNext Movement v2 - Event Driven
-- Replaces per-frame IsOnGround() raycast polling
-- with Humanoid.StateChanged event.
-- FPS cost: near zero when idle.
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")

local Movement = {}

local DEFAULTS = {
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
    MovementProfile       = "Generic",
    BloxstrikeSpeedCap    = 85,
    BloxstrikeStrafePower = 8,
    BloxstrikeLandingBleed   = true,
    BloxstrikeBleedThreshold = 40,
    BloxstrikeBleedRate      = 12,
    BloxstrikeBleedDistance  = 6,
}

local function EnsureSettings()
    local S  = State.Settings
    local DS = State.DefaultSettings
    for k, v in pairs(DEFAULTS) do
        if S[k]  == nil then S[k]  = v end
        if DS[k] == nil then DS[k] = v end
    end
end

-- ==========================================
-- GROUND STATE (event-driven)
-- Instead of raycasting every frame,
-- we listen to Humanoid.StateChanged.
-- This fires ONLY when state changes,
-- costing zero CPU between events.
-- ==========================================
local onGround          = true   -- current ground state
local stateChangedConn  = nil    -- connection to current humanoid
local lastHumanoid      = nil    -- track which humanoid we're connected to

local function OnStateChanged(_, newState)
    if newState == Enum.HumanoidStateType.Landed
    or newState == Enum.HumanoidStateType.Running
    or newState == Enum.HumanoidStateType.RunningNoPhysics
    or newState == Enum.HumanoidStateType.Seated then
        onGround = true
    elseif newState == Enum.HumanoidStateType.Jumping
    or newState == Enum.HumanoidStateType.Freefall then
        onGround = false
    end
end

local function ConnectHumanoidEvents(hum)
    if hum == lastHumanoid then return end
    -- Disconnect previous
    if stateChangedConn then
        pcall(function() stateChangedConn:Disconnect() end)
        stateChangedConn = nil
    end
    if not hum then return end
    -- Connect new
    local ok, conn = pcall(function()
        return hum.StateChanged:Connect(OnStateChanged)
    end)
    if ok and conn then
        stateChangedConn = conn
        lastHumanoid     = hum
        -- Set initial state
        local ok2, state = pcall(function()
            return hum:GetState()
        end)
        if ok2 then OnStateChanged(nil, state) end
    end
end

-- ==========================================
-- SAFE CHARACTER HELPERS
-- ==========================================
local function GetCharacterState()
    local ok, c, h, hu = pcall(function()
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
    return c, h, hu
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
-- INTERNAL STATE
-- ==========================================
local wasOnGround      = true
local jumpQueued       = false
local scrollJumpQueued = false
local jumpCooldown     = 0
local scrollConn       = nil
local characterConn    = nil
local initDone         = false

local MAX_DT       = 0.05
local MAX_IMPULSE  = 8.0
local BHOP_COOLDOWN= 0.40

-- ==========================================
-- BHOP: GENERIC
-- ==========================================
local function HandleGenericBhop(hum, dt)
    local S   = State.Settings
    local UIS = Services.UserInputService
    jumpCooldown = math.max(0, jumpCooldown - dt)

    if S.BhopMode == "Auto" then
        -- Queue jump when we land
        if onGround and not wasOnGround then
            jumpQueued = true
        end
        if jumpQueued and onGround and jumpCooldown <= 0 then
            SafeJump(hum)
            jumpQueued   = false
            jumpCooldown = BHOP_COOLDOWN
        end

    elseif S.BhopMode == "Scroll" then
        if scrollJumpQueued and onGround and jumpCooldown <= 0 then
            SafeJump(hum)
            scrollJumpQueued = false
            jumpCooldown     = BHOP_COOLDOWN
        end

    elseif S.BhopMode == "Space" then
        local held = false
        pcall(function() held = UIS:IsKeyDown(Enum.KeyCode.Space) end)
        if held and onGround and jumpCooldown <= 0 then
            SafeJump(hum)
            jumpCooldown = BHOP_COOLDOWN
        end
    end
end

-- ==========================================
-- BHOP: STATE SKIP NO-COOLDOWN
-- ==========================================
local function HandleStateSkip(hum)
    if onGround and not wasOnGround then
        pcall(function()
            hum:SetStateEnabled(
                Enum.HumanoidStateType.GettingUp, false)
            hum:ChangeState(Enum.HumanoidStateType.Running)
            task.defer(function()
                pcall(function()
                    hum:SetStateEnabled(
                        Enum.HumanoidStateType.GettingUp, true)
                end)
            end)
        end)
        task.defer(function()
            pcall(function()
                if hum and hum.Health > 0 then
                    hum.Jump = true
                end
            end)
        end)
    end
end

-- ==========================================
-- BHOP: BLOXSTRIKE
-- Space held → jump on ground, strafe in air
-- ==========================================
local function HandleBloxstrikeBhop(hrp, hum, dt)
    local S   = State.Settings
    local UIS = Services.UserInputService

    local spaceHeld = false
    pcall(function() spaceHeld = UIS:IsKeyDown(Enum.KeyCode.Space) end)
    if not spaceHeld then return end

    if onGround then
        pcall(function() hum.Jump = true end)
        return
    end

    -- Airborne: bleed + strafe
    if not S.AirStrafeEnabled then return end

    -- Pre-land bleed
    if S.BloxstrikeLandingBleed then
        local vel = Vector3.new(0,0,0)
        pcall(function() vel = hrp.AssemblyLinearVelocity end)
        if vel.Y < 0 then
            local hMag = Vector3.new(vel.X,0,vel.Z).Magnitude
            local threshold = math.clamp(S.BloxstrikeBleedThreshold, 10, 200)
            if hMag > threshold then
                local rate = math.clamp(S.BloxstrikeBleedRate / 100, 0.01, 0.5)
                local newMag = hMag - (hMag - threshold) * rate
                newMag = math.clamp(newMag, threshold, hMag)
                if hMag > 0.001 then
                    local unit = Vector3.new(vel.X,0,vel.Z).Unit
                    if unit == unit then
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.new(
                                unit.X * newMag,
                                vel.Y,
                                unit.Z * newMag
                            )
                        end)
                    end
                end
            end
        end
    end

    -- Air strafe: direct velocity addition
    local moveDir = Vector3.new(0,0,0)
    pcall(function() moveDir = hum.MoveDirection end)
    if moveDir.Magnitude <= 0.01 then return end

    local currentVel = Vector3.new(0,0,0)
    pcall(function() currentVel = hrp.AssemblyLinearVelocity end)
    if currentVel ~= currentVel then return end

    local power    = math.clamp(S.BloxstrikeStrafePower, 1, 50)
    local speedCap = math.clamp(S.BloxstrikeSpeedCap, 20, 300)
    local boost    = moveDir * power
    local newVel   = Vector3.new(
        currentVel.X + boost.X,
        currentVel.Y,
        currentVel.Z + boost.Z
    )

    local hMag = Vector3.new(newVel.X, 0, newVel.Z).Magnitude
    if hMag > speedCap and hMag > 0.001 then
        local unit = Vector3.new(newVel.X, 0, newVel.Z).Unit
        if unit == unit then
            newVel = Vector3.new(
                unit.X * speedCap,
                newVel.Y,
                unit.Z * speedCap
            )
        end
    end

    pcall(function() hrp.AssemblyLinearVelocity = newVel end)
end

-- ==========================================
-- AIR STRAFE: GENERIC (impulse-based)
-- ==========================================
local function HandleGenericAirStrafe(hrp, hum, dt)
    if onGround then return end

    local S      = State.Settings
    local Camera = Services.Camera
    local UIS    = Services.UserInputService

    -- Get strafe direction
    local camLook  = Vector3.new(0,0,-1)
    local camRight = Vector3.new(1,0,0)
    pcall(function()
        camLook  = Camera.CFrame.LookVector
        camRight = Camera.CFrame.RightVector
    end)

    local fL = Vector3.new(camLook.X, 0, camLook.Z)
    local fR = Vector3.new(camRight.X, 0, camRight.Z)
    if fL.Magnitude < 0.001 then fL = Vector3.new(0,0,-1) end
    if fR.Magnitude < 0.001 then fR = Vector3.new(1,0,0)  end
    fL = fL.Unit
    fR = fR.Unit

    local wD, sD, aD, dD = false, false, false, false
    pcall(function()
        wD = UIS:IsKeyDown(Enum.KeyCode.W)
        sD = UIS:IsKeyDown(Enum.KeyCode.S)
        aD = UIS:IsKeyDown(Enum.KeyCode.A)
        dD = UIS:IsKeyDown(Enum.KeyCode.D)
    end)

    local wasd = Vector3.new(0,0,0)
    if wD then wasd = wasd + fL end
    if sD then wasd = wasd - fL end
    if aD then wasd = wasd - fR end
    if dD then wasd = wasd + fR end

    local mode   = S.AirStrafeMode
    local result = Vector3.new(0,0,0)

    if mode == "Camera" then
        result = fL
    elseif mode == "WASD" then
        if wasd.Magnitude < 0.001 then return end
        result = wasd
    elseif mode == "Combined" then
        local blend = fL + wasd
        result = blend.Magnitude > 0.001 and blend or fL
    end

    if result.Magnitude < 0.001 then return end
    local dir = result.Unit
    if dir ~= dir then return end  -- nan check

    local vel = Vector3.new(0,0,0)
    if not pcall(function() vel = hrp.AssemblyLinearVelocity end) then
        return
    end

    local accel    = math.clamp(S.BhopAcceleration  / 100, 0.05, 1.0)
    local maxSpeed = math.clamp(S.BhopMaxSpeed,             10,   500)
    local strength = math.clamp(S.AirStrafeStrength / 100, 0.01, 1.0)
                   * maxSpeed

    local hVel = Vector3.new(vel.X, 0, vel.Z)
    local proj  = hVel:Dot(dir)
    if proj >= strength then return end

    local safeDt = math.clamp(dt, 0.001, MAX_DT)
    local raw    = dir * (strength - proj) * accel * safeDt * 20
    local mag    = raw.Magnitude
    if mag ~= mag or mag < 0.0001 then return end

    local impulse = mag > MAX_IMPULSE and raw.Unit * MAX_IMPULSE or raw

    local mass = 1.0
    pcall(function()
        local m = hrp.AssemblyMass
        if m and m == m and m > 0 then mass = m end
    end)

    pcall(function()
        hrp:ApplyImpulse(
            Vector3.new(impulse.X * mass, 0, impulse.Z * mass)
        )
    end)
end

-- ==========================================
-- TICK — called every frame from lifecycle
-- Much lighter: no raycast, no FloorMaterial poll.
-- Ground state comes from event.
-- ==========================================
function Movement.Tick(dt)
    local S = State.Settings
    if not S.BhopEnabled and not S.AirStrafeEnabled then
        wasOnGround = onGround
        return
    end

    local safeDt = math.clamp(dt or 0.016, 0.001, MAX_DT)

    local char, hrp, hum = GetCharacterState()
    if not char then
        wasOnGround = true
        onGround    = true
        return
    end

    -- Keep humanoid event connection fresh
    -- (cheap check: only reconnects on respawn)
    ConnectHumanoidEvents(hum)

    local profile = S.MovementProfile or "Generic"

    if profile == "Bloxstrike" then
        if S.BhopEnabled or S.AirStrafeEnabled then
            pcall(HandleBloxstrikeBhop, hrp, hum, safeDt)
        end
    else
        if S.BhopEnabled then
            if S.BhopNoCooldown
            and S.BhopNoCooldownMethod == "StateSkip" then
                pcall(HandleStateSkip, hum)
            else
                pcall(HandleGenericBhop, hum, safeDt)
            end
        end
        if S.AirStrafeEnabled then
            pcall(HandleGenericAirStrafe, hrp, hum, safeDt)
        end
    end

    wasOnGround = onGround
end

-- ==========================================
-- CHARACTER RESPAWN HANDLER
-- Re-connects humanoid events after respawn.
-- ==========================================
local function OnCharacterAdded(char)
    onGround     = true
    wasOnGround  = true
    jumpQueued   = false
    jumpCooldown = 0
    lastHumanoid = nil  -- force reconnect on next Tick

    -- Slight delay for character to fully load
    task.delay(0.5, function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then ConnectHumanoidEvents(hum) end
    end)
end

-- ==========================================
-- INIT
-- ==========================================
function Movement.Init()
    if initDone then EnsureSettings() return end
    EnsureSettings()

    local lp = Services.LocalPlayer

    -- Character respawn connection
    characterConn = lp.CharacterAdded:Connect(OnCharacterAdded)
    table.insert(State.GlobalConnections, characterConn)

    -- Connect to current character if already exists
    if lp.Character then
        OnCharacterAdded(lp.Character)
    end

    -- Scroll wheel listener (only for Scroll bhop mode)
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
    onGround         = true
    wasOnGround      = true
    jumpQueued       = false
    scrollJumpQueued = false
    jumpCooldown     = 0
    initDone         = false
    lastHumanoid     = nil

    if stateChangedConn then
        pcall(function() stateChangedConn:Disconnect() end)
        stateChangedConn = nil
    end
    if scrollConn then
        pcall(function() scrollConn:Disconnect() end)
        scrollConn = nil
    end
    if characterConn then
        pcall(function() characterConn:Disconnect() end)
        characterConn = nil
    end

    -- Re-enable GettingUp state in case we left it disabled
    pcall(function()
        local char = Services.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(
                Enum.HumanoidStateType.GettingUp, true)
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