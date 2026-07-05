-- core/lifecycle.lua
-- AimHubNext Script Lifecycle Manager
-- Handles:
--   - Cross-script hot-reload state transfer
--   - Legacy script/GUI cleanup
--   - UniversalDestruct (full teardown)
--   - Input binding (aim key, UI toggle key)
-- Mod Author: CookieLee

local State      = require(script.Parent.state)
local Services   = require(script.Parent.services)
local Utils      = require(script.Parent.utils)

-- Engine modules (loaded after core)
-- These are passed in via Lifecycle.Init()
-- to avoid circular requires at load time.
local _Aimbot    = nil
local _Chams     = nil
local _ESP       = nil
local _Drawings  = nil
local _Rage      = nil
local _AntiAim   = nil
local _SilentAim = nil
local _UIRef     = nil  -- reference to main UI frame for toggle

local Lifecycle = {}

-- ==========================================
-- HOT-RELOAD STATE TRANSFER
-- If a previous version of this script is
-- running, call its destructor first, then
-- recover any saved state it left behind.
-- ==========================================
function Lifecycle.HandleHotReload()
    local env = State.env
    local id  = State.CurrentScriptID

    -- Trigger previous instance cleanup
    if env[id] then
        pcall(env[id])
        env[id] = nil
    end

    -- Recover saved state packet if present
    local packetKey = id .. "_DataPacket"
    if env[packetKey] then
        local saved = env[packetKey]
        env[packetKey] = nil

        -- Restore settings from previous session
        if type(saved) == "table" and saved.Settings then
            for k, v in pairs(saved.Settings) do
                if State.Settings[k] ~= nil then
                    State.Settings[k] = v
                end
            end
        end
    end
end

-- ==========================================
-- LEGACY CLEANUP
-- Kills old GUI instances and destructor
-- functions left by previous script versions.
-- ==========================================
function Lifecycle.CleanupLegacy()
    local env       = State.env
    local PlayerGui = Services.PlayerGui
    local RunService= Services.RunService

    -- Unbind any leftover render step from old versions
    pcall(function()
        RunService:UnbindFromRenderStep("AimLockCameraUpdate")
    end)

    for _, legacyID in ipairs(State.LegacyIDs) do
        -- Call legacy destructor if present
        if env[legacyID] then
            pcall(env[legacyID])
            env[legacyID] = nil
        end
        -- Destroy legacy GUI
        local oldGui = PlayerGui:FindFirstChild(legacyID)
        if oldGui then
            pcall(function() oldGui:Destroy() end)
        end
    end
end

-- ==========================================
-- UNIVERSAL DESTRUCT
-- Full teardown of all systems.
-- Registered into env[CurrentScriptID] so
-- the next inject can trigger it.
-- ==========================================
function Lifecycle.UniversalDestruct()
    local RunService = Services.RunService
    local PlayerGui  = Services.PlayerGui

    -- Unbind render loop
    pcall(function()
        RunService:UnbindFromRenderStep("AimLockCameraUpdate")
    end)

    -- Disconnect all registered signals
    for _, con in ipairs(State.GlobalConnections) do
        if con and con.Disconnect then
            pcall(function() con:Disconnect() end)
        end
    end
    State.GlobalConnections = {}

    -- Stop any active shooting
    Utils.ControlClick(false)

    -- Restore hitboxes
    Utils.ResetHitboxes()

    -- Remove drawing objects
    if _Drawings then
        pcall(function() _Drawings.Cleanup() end)
    end

    -- Remove ESP / Chams highlights
    if _Chams then
        pcall(function() _Chams.Cleanup() end)
    end
    if _ESP then
        pcall(function() _ESP.Cleanup() end)
    end

    -- Aimbot cleanup
    if _Aimbot then
        pcall(function() _Aimbot.Cleanup() end)
    end

    -- Rage cleanup
    if _Rage then
        pcall(function() _Rage.Cleanup() end)
    end

    -- Silent aim hook removal (best effort)
    if _SilentAim then
        pcall(function() _SilentAim.Uninstall() end)
    end

    -- Destroy GUI
    pcall(function()
        local gui = PlayerGui:FindFirstChild(State.CurrentScriptID)
        if gui then gui:Destroy() end
    end)

    -- Clear env registration
    State.env[State.CurrentScriptID] = nil
    State.env[State.CurrentScriptID .. "_DataPacket"] = nil
end

-- ==========================================
-- REGISTER DESTRUCTOR
-- Called after full init so env holds a
-- valid reference for the next inject.
-- ==========================================
function Lifecycle.RegisterDestructor()
    State.env[State.CurrentScriptID] = Lifecycle.UniversalDestruct
end

-- ==========================================
-- SAVE STATE FOR HOT-RELOAD
-- Called just before CinematicClose so the
-- next inject can restore user settings.
-- ==========================================
function Lifecycle.SaveStatePacket()
    local packetKey = State.CurrentScriptID .. "_DataPacket"
    State.env[packetKey] = {
        Settings = State.Settings,
    }
end

-- ==========================================
-- BIND INPUT
-- Aim key and UI toggle key handling.
-- Requires UIRef to be set via Init().
-- ==========================================
local function UpdateShortcutDisplay()
    if _UIRef and _UIRef.UpdateShortcuts then
        _UIRef.UpdateShortcuts()
    end
end

function Lifecycle.BindInput()
    local UIS = Services.UserInputService
    local S   = State.Settings

    Utils.SafeConnect(UIS.InputBegan, function(input, processed)
        if processed then return end

        -- Aim key
        if input.KeyCode == S.AimKey then
            if S.AimMode == "Toggle" then
                State.Aiming = not State.Aiming
                if not State.Aiming then
                    Utils.ControlClick(false)
                end
            elseif S.AimMode == "Hold" then
                State.Aiming = true
            end
            UpdateShortcutDisplay()
        end

        -- UI minimize toggle key
        if input.KeyCode == S.ToggleUiKey then
            if _UIRef and _UIRef.ToggleMinimize then
                _UIRef.ToggleMinimize()
            end
        end
    end)

    Utils.SafeConnect(UIS.InputEnded, function(input, processed)
        -- Release aim on Hold mode key up
        if input.KeyCode == S.AimKey and S.AimMode == "Hold" then
            State.Aiming = false
            Utils.ControlClick(false)
            UpdateShortcutDisplay()
        end
    end)
end

-- ==========================================
-- BIND RENDER LOOP
-- Main per-frame update pipeline.
-- All engine ticks are called from here.
-- ==========================================
function Lifecycle.BindRenderLoop()
    local RunService = Services.RunService

    RunService:BindToRenderStep(
        "AimLockCameraUpdate",
        Enum.RenderPriority.Camera.Value + 1,
        function(deltaTime)
            pcall(function()
                deltaTime = deltaTime or 0.016
                local currentTime = tick()

                -- Silent aim confidence gate
                if _SilentAim then
                    _SilentAim.TickConfidence()
                end

                -- Drawing: FOV circle
                if _Drawings then
                    _Drawings.UpdateFOV(State.Aiming, currentTime)
                end

                -- Chams (throttled internally)
                if _Chams then
                    _Chams.Tick(currentTime)
                end

                -- Legacy ESP (every frame, lightweight)
                if _ESP then
                    _ESP.Tick()
                end

                -- Rage: hitbox expander + kill aura (throttled internally)
                if _Rage then
                    _Rage.Tick(currentTime)
                end

                -- Anti-aim (every frame, lightweight math)
                if _AntiAim then
                    _AntiAim.Tick(deltaTime)
                end

                -- Aimbot core (every frame)
                if _Aimbot then
                    _Aimbot.Tick(deltaTime)
                end
            end)
        end
    )
end

-- ==========================================
-- INIT
-- Called from main.lua after all modules
-- are loaded. Receives module references
-- so lifecycle can call their methods
-- without circular require chains.
-- ==========================================
function Lifecycle.Init(modules)
    _Aimbot    = modules.Aimbot
    _Chams     = modules.Chams
    _ESP       = modules.ESP
    _Drawings  = modules.Drawings
    _Rage      = modules.Rage
    _AntiAim   = modules.AntiAim
    _SilentAim = modules.SilentAim
    _UIRef     = modules.UI
end

-- ==========================================
-- CINEMATIC CLOSE
-- Animated shutdown sequence.
-- Saves state, plays close animation,
-- then calls UniversalDestruct.
-- Requires UIRef for animation.
-- ==========================================
function Lifecycle.CinematicClose()
    Lifecycle.SaveStatePacket()

    if _UIRef and _UIRef.PlayCloseAnimation then
        -- UI module plays the animation then
        -- calls the callback when done
        _UIRef.PlayCloseAnimation(function()
            State.env[State.CurrentScriptID] = nil
            State.env[State.CurrentScriptID .. "_DataPacket"] = nil
            Lifecycle.UniversalDestruct()
        end)
    else
        -- No UI available, just destruct immediately
        Lifecycle.UniversalDestruct()
    end
end

return Lifecycle