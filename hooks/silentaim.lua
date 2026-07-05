-- hooks/silentaim.lua
-- AimHubNext Silent Aim Metamethod Hook
-- Redirects mouse.Hit / mouse.Target / mouse.X / mouse.Y
-- toward the locked target's hit part without moving camera.
--
-- Blank-fire mitigation:
--   Only redirects when State.Aiming is true AND
--   a confirmed valid hitPart exists in workspace.
--   Adds a frame-delay confidence check so the hook
--   doesn't redirect on the same frame aiming starts.
--
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)
local Rage     = require(script.Parent.Parent.engine.rage)

local SilentAim = {}

-- Track whether we successfully installed the hook
SilentAim.Hooked = false

-- ==========================================
-- CONFIDENCE GATE
-- Prevents redirecting on the very first frame
-- aiming starts (avoids blank-fire on aim begin).
-- Counts frames since aiming started.
-- ==========================================
local aimingFrameCount = 0
local CONFIDENCE_FRAMES = 2  -- require N frames of aiming before redirecting

-- Called from the render loop every frame
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

-- ==========================================
-- RESOLVE CURRENT HIT PART
-- Returns the BasePart we want mouse.Hit
-- to point at, or nil if not ready.
-- Nil causes the hook to fall through to
-- the original __index, no redirect happens.
-- ==========================================
local function ResolveHitPart()
    local S = State.Settings

    if not S.SilentAim then return nil end
    if not S.Enabled    then return nil end
    if not State.Aiming then return nil end
    if not IsConfident() then return nil end

    local target = State.Target
    if not target or not target.Character then return nil end

    -- Validate target is still alive
    local hum = target.Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end

    -- Resolve which part to redirect to
    local hitPart
    if S.RageEnabled then
        hitPart = Rage.GetRageHitPart(target.Character)
    else
        hitPart = target.Character:FindFirstChild(S.TargetPart)
               or target.Character:FindFirstChild("HumanoidRootPart")
    end

    -- Final safety: part must still exist in workspace hierarchy
    if not hitPart then return nil end
    if not hitPart:IsDescendantOf(workspace) then return nil end

    return hitPart
end

-- ==========================================
-- INSTALL HOOK
-- Uses getrawmetatable + setreadonly pattern.
-- Fully wrapped in pcall layers so failure
-- is silent and non-breaking.
-- Only installs once per session (guard flag).
-- ==========================================
function SilentAim.Install()
    -- Already hooked this session
    if SilentAim.Hooked then return end

    -- Executor capability check
    if not getrawmetatable then return end
    if not newcclosure     then return end
    if not setreadonly     then return end

    local success = pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end

        -- Prevent double-hooking across re-injects
        if mt.__AimHubNext_SilentHooked then
            SilentAim.Hooked = true
            return
        end

        local oldIndex = rawget(mt, "__index")
        if not oldIndex then return end

        setreadonly(mt, false)
        mt.__AimHubNext_SilentHooked = true

        mt.__index = newcclosure(function(self, key)
            -- Only intercept Mouse / PlayerMouse instances
            local isMouse = false
            pcall(function()
                isMouse = typeof(self) == "Instance"
                      and (self.ClassName == "Mouse"
                        or self.ClassName == "PlayerMouse")
            end)

            if isMouse then
                -- Attempt to resolve a confirmed hit part
                local hitPart = nil
                pcall(function()
                    hitPart = ResolveHitPart()
                end)

                if hitPart then
                    -- Redirect relevant mouse properties
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
                    -- All other mouse keys fall through normally
                end
            end

            -- Default: call original __index
            return oldIndex(self, key)
        end)

        setreadonly(mt, true)
        SilentAim.Hooked = true
    end)

    if not success then
        -- Hook failed silently, SilentAim just won't redirect
        -- The aimbot still works normally without it
        SilentAim.Hooked = false
    end
end

-- ==========================================
-- UNINSTALL HOOK
-- Best-effort removal on script unload.
-- Note: some executors don't allow removing
-- metamethod hooks after install. We flag
-- the hook as inactive so ResolveHitPart()
-- returns nil immediately, effectively
-- disabling redirection without crashing.
-- ==========================================
function SilentAim.Uninstall()
    -- Force confidence gate to zero so no
    -- further redirects happen even if the
    -- metamethod hook physically remains
    aimingFrameCount = 0

    -- Attempt physical removal
    pcall(function()
        if not getrawmetatable then return end
        local mt = getrawmetatable(game)
        if not mt then return end

        -- Clear our guard flag so a future
        -- fresh inject can re-hook cleanly
        setreadonly(mt, false)
        mt.__AimHubNext_SilentHooked = nil
        setreadonly(mt, true)
    end)

    SilentAim.Hooked = false
end

return SilentAim