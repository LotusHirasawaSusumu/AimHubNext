-- hooks/silentaim.lua
-- AimHubNext Silent Aim Hook
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Rage     = require("engine/rage.lua")

local SilentAim = {}
SilentAim.Hooked = false

local aimingFrameCount  = 0
local CONFIDENCE_FRAMES = 2

function SilentAim.TickConfidence()
    if State.Aiming then
        if aimingFrameCount < CONFIDENCE_FRAMES then
            aimingFrameCount = aimingFrameCount + 1
        end
    else
        aimingFrameCount = 0
    end
end

local function IsConfident()
    return aimingFrameCount >= CONFIDENCE_FRAMES
end

local function ResolveHitPart()
    local S = State.Settings
    if not S.SilentAim or not S.Enabled then return nil end
    if not State.Aiming or not IsConfident() then return nil end
    local target = State.Target
    if not target or not target.Character then return nil end
    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    local hitPart
    if S.RageEnabled then
        hitPart = Rage.GetRageHitPart(target.Character)
    else
        hitPart = target.Character:FindFirstChild(S.TargetPart)
               or target.Character:FindFirstChild("HumanoidRootPart")
    end
    if not hitPart then return nil end
    if not hitPart:IsDescendantOf(workspace) then return nil end
    return hitPart
end

function SilentAim.Install()
    if SilentAim.Hooked then return end
    if not getrawmetatable or not newcclosure or not setreadonly then return end
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end
        if mt.__AimHubNext_SilentHooked then
            SilentAim.Hooked = true
            return
        end
        local oldIndex = rawget(mt, "__index")
        if not oldIndex then return end
        setreadonly(mt, false)
        mt.__AimHubNext_SilentHooked = true
        mt.__index = newcclosure(function(self, key)
            local isMouse = false
            pcall(function()
                isMouse = typeof(self) == "Instance"
                      and (self.ClassName == "Mouse"
                        or self.ClassName == "PlayerMouse")
            end)
            if isMouse then
                local hitPart = nil
                pcall(function() hitPart = ResolveHitPart() end)
                if hitPart then
                    if key == "Hit" then
                        return CFrame.new(hitPart.Position)
                    elseif key == "Target" then
                        return hitPart
                    elseif key == "X" then
                        local pos = Services.Camera
                            :WorldToViewportPoint(hitPart.Position)
                        return pos.X
                    elseif key == "Y" then
                        local pos = Services.Camera
                            :WorldToViewportPoint(hitPart.Position)
                        return pos.Y
                    end
                end
            end
            return oldIndex(self, key)
        end)
        setreadonly(mt, true)
        SilentAim.Hooked = true
    end)
    if not ok then SilentAim.Hooked = false end
end

function SilentAim.Uninstall()
    aimingFrameCount = 0
    pcall(function()
        if not getrawmetatable then return end
        local mt = getrawmetatable(game)
        if not mt then return end
        setreadonly(mt, false)
        mt.__AimHubNext_SilentHooked = nil
        setreadonly(mt, true)
    end)
    SilentAim.Hooked = false
end

return SilentAim