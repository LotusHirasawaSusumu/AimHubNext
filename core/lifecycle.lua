-- core/lifecycle.lua
-- AimHubNext Lifecycle Manager
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Utils    = require("core/utils.lua")

local _Aimbot    = nil
local _Chams     = nil
local _ESP       = nil
local _Drawings  = nil
local _Rage      = nil
local _AntiAim   = nil
local _SilentAim = nil
local _UIRef     = nil
local _Movement  = nil

local Lifecycle = {}

function Lifecycle.HandleHotReload()
    local env = State.env
    local id  = State.CurrentScriptID
    if env[id] then
        pcall(env[id])
        env[id] = nil
    end
    local packetKey = id .. "_DataPacket"
    if env[packetKey] then
        local saved = env[packetKey]
        env[packetKey] = nil
        if type(saved) == "table" and saved.Settings then
            for k, v in pairs(saved.Settings) do
                if State.Settings[k] ~= nil then
                    State.Settings[k] = v
                end
            end
        end
    end
end

function Lifecycle.CleanupLegacy()
    local env        = State.env
    local PlayerGui  = Services.PlayerGui
    local RunService = Services.RunService
    pcall(function()
        RunService:UnbindFromRenderStep("AimLockCameraUpdate")
    end)
    for _, legacyID in ipairs(State.LegacyIDs) do
        if env[legacyID] then
            pcall(env[legacyID])
            env[legacyID] = nil
        end
        local oldGui = PlayerGui:FindFirstChild(legacyID)
        if oldGui then
            pcall(function() oldGui:Destroy() end)
        end
    end
end

function Lifecycle.UniversalDestruct()
    local RunService = Services.RunService
    local PlayerGui  = Services.PlayerGui
    pcall(function()
        RunService:UnbindFromRenderStep("AimLockCameraUpdate")
    end)
    for _, con in ipairs(State.GlobalConnections) do
        if con and con.Disconnect then
            pcall(function() con:Disconnect() end)
        end
    end
    State.GlobalConnections = {}
    Utils.ControlClick(false)
    Utils.ResetHitboxes()
    if _Drawings  then pcall(function() _Drawings.Cleanup()  end) end
    if _Chams     then pcall(function() _Chams.Cleanup()     end) end
    if _ESP       then pcall(function() _ESP.Cleanup()       end) end
    if _Aimbot    then pcall(function() _Aimbot.Cleanup()    end) end
    if _Rage      then pcall(function() _Rage.Cleanup()      end) end
    if _SilentAim then pcall(function() _SilentAim.Uninstall() end) end
    if _Movement  then pcall(function() _Movement.Cleanup()  end) end
    pcall(function()
        local gui = PlayerGui:FindFirstChild(State.CurrentScriptID)
        if gui then gui:Destroy() end
    end)
    State.env[State.CurrentScriptID] = nil
    State.env[State.CurrentScriptID .. "_DataPacket"] = nil
end

function Lifecycle.RegisterDestructor()
    State.env[State.CurrentScriptID] = Lifecycle.UniversalDestruct
end

function Lifecycle.SaveStatePacket()
    local packetKey = State.CurrentScriptID .. "_DataPacket"
    State.env[packetKey] = { Settings = State.Settings }
end

function Lifecycle.Init(modules)
    _Aimbot    = modules.Aimbot
    _Chams     = modules.Chams
    _ESP       = modules.ESP
    _Drawings  = modules.Drawings
    _Rage      = modules.Rage
    _AntiAim   = modules.AntiAim
    _SilentAim = modules.SilentAim
    _UIRef     = modules.UI
    _Movement  = modules.Movement
end

function Lifecycle.BindInput()
    local UIS = Services.UserInputService
    local S   = State.Settings
    Utils.SafeConnect(UIS.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == S.AimKey then
            if S.AimMode == "Toggle" then
                State.Aiming = not State.Aiming
                if not State.Aiming then Utils.ControlClick(false) end
            elseif S.AimMode == "Hold" then
                State.Aiming = true
            end
            if _UIRef and _UIRef.UpdateShortcuts then
                _UIRef.UpdateShortcuts()
            end
        end
        if input.KeyCode == S.ToggleUiKey then
            if _UIRef and _UIRef.ToggleMinimize then
                _UIRef.ToggleMinimize()
            end
        end
    end)
    Utils.SafeConnect(UIS.InputEnded, function(input, processed)
        if input.KeyCode == S.AimKey and S.AimMode == "Hold" then
            State.Aiming = false
            Utils.ControlClick(false)
            if _UIRef and _UIRef.UpdateShortcuts then
                _UIRef.UpdateShortcuts()
            end
        end
    end)
end

function Lifecycle.BindRenderLoop()
    local RunService = Services.RunService
    RunService:BindToRenderStep(
        "AimLockCameraUpdate",
        Enum.RenderPriority.Camera.Value + 1,
        function(deltaTime)
            pcall(function()
                deltaTime = deltaTime or 0.016
                local currentTime = tick()
                if _SilentAim then _SilentAim.TickConfidence() end
                if _Drawings  then _Drawings.UpdateFOV(State.Aiming, currentTime) end
                if _Chams     then _Chams.Tick(currentTime) end
                if _ESP       then _ESP.Tick() end
                if _Rage      then _Rage.Tick(currentTime) end
                if _AntiAim   then _AntiAim.Tick(deltaTime) end
                if _Aimbot    then _Aimbot.Tick(deltaTime) end
                if _Movement  then _Movement.Tick(deltaTime) end
            end)
        end
    )
end

function Lifecycle.CinematicClose()
    Lifecycle.SaveStatePacket()
    if _UIRef and _UIRef.PlayCloseAnimation then
        _UIRef.PlayCloseAnimation(function()
            State.env[State.CurrentScriptID] = nil
            State.env[State.CurrentScriptID .. "_DataPacket"] = nil
            Lifecycle.UniversalDestruct()
        end)
    else
        Lifecycle.UniversalDestruct()
    end
end

return Lifecycle
