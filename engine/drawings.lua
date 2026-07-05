-- engine/drawings.lua
-- AimHubNext Drawing Objects Manager
-- FOV Circle, Target Dot, Snap Line
-- Mod Author: CookieLee

local State    = require(script.Parent.Parent.core.state)
local Services = require(script.Parent.Parent.core.services)
local Styles   = require(script.Parent.Parent.core.styles)

local Drawings = {}

-- ==========================================
-- CREATE DRAWING OBJECTS
-- Called once on startup.
-- ==========================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color     = Styles.Accent
FOVCircle.Thickness = 1.5
FOVCircle.NumSides  = 64
FOVCircle.Filled    = false
FOVCircle.Visible   = false

local TargetDot = Drawing.new("Circle")
TargetDot.Color     = Styles.Accent
TargetDot.Thickness = 1
TargetDot.Filled    = true
TargetDot.Radius    = 4
TargetDot.Visible   = false
TargetDot.ZIndex    = 2

local SnapLine = Drawing.new("Line")
SnapLine.Color        = Styles.Accent
SnapLine.Thickness    = 1
SnapLine.Visible      = false
SnapLine.Transparency = 0.6

-- ==========================================
-- PUBLIC ACCESSORS
-- Other modules read these to update positions.
-- ==========================================
Drawings.FOVCircle = FOVCircle
Drawings.TargetDot = TargetDot
SnapLine.Visible   = false
Drawings.SnapLine  = SnapLine

-- ==========================================
-- UPDATE FOV CIRCLE
-- Called every frame from the render loop.
-- ==========================================
function Drawings.UpdateFOV(aiming, currentTime)
    local UIS = Services.UserInputService
    local S   = State.Settings

    FOVCircle.Position = UIS:GetMouseLocation()

    if S.Enabled and aiming and S.FOVPulse then
        local pulseOffset   = math.sin(currentTime * 6) * (S.FOVRadius * 0.06)
        FOVCircle.Radius        = S.FOVRadius + pulseOffset
        FOVCircle.Transparency  = 0.5 + (math.sin(currentTime * 6) * 0.5)
    else
        FOVCircle.Radius       = S.FOVRadius
        FOVCircle.Transparency = 1
    end

    FOVCircle.Visible = S.Enabled and S.ShowFOV
end

-- ==========================================
-- UPDATE TARGET INDICATOR
-- Shows dot on target and snap line from mouse.
-- Pass nil targetPosition to hide both.
-- ==========================================
function Drawings.UpdateTargetIndicator(targetPosition)
    local Camera = Services.Camera
    local UIS    = Services.UserInputService
    local S      = State.Settings

    if not S.TargetIndicator or not targetPosition then
        TargetDot.Visible = false
        SnapLine.Visible  = false
        return
    end

    local pos, onScreen = Camera:WorldToViewportPoint(targetPosition)

    if onScreen then
        local screenPos = Vector2.new(pos.X, pos.Y)
        TargetDot.Position = screenPos
        TargetDot.Visible  = true

        SnapLine.From    = UIS:GetMouseLocation()
        SnapLine.To      = screenPos
        SnapLine.Visible = true
    else
        TargetDot.Visible = false
        SnapLine.Visible  = false
    end
end

-- ==========================================
-- HIDE ALL INDICATORS
-- Called when not aiming or no target.
-- ==========================================
function Drawings.HideIndicators()
    TargetDot.Visible = false
    SnapLine.Visible  = false
end

-- ==========================================
-- REFRESH ACCENT COLOR
-- Called when user swaps accent color.
-- ==========================================
function Drawings.RefreshAccent()
    local c = Styles.Accent
    FOVCircle.Color = c
    TargetDot.Color = c
    SnapLine.Color  = c
end

-- ==========================================
-- CLEANUP
-- Removes all drawing objects permanently.
-- ==========================================
function Drawings.Cleanup()
    pcall(function() FOVCircle:Remove() end)
    pcall(function() TargetDot:Remove() end)
    pcall(function() SnapLine:Remove() end)
end

return Drawings