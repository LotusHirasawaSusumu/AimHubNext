-- engine/drawings.lua
-- AimHubNext Drawing Objects Manager
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")
local Services = require("core/services.lua")
local Styles   = require("core/styles.lua")

local Drawings = {}

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

Drawings.FOVCircle = FOVCircle
Drawings.TargetDot = TargetDot
Drawings.SnapLine  = SnapLine

function Drawings.UpdateFOV(aiming, currentTime)
    local UIS = Services.UserInputService
    local S   = State.Settings
    FOVCircle.Position = UIS:GetMouseLocation()
    if S.Enabled and aiming and S.FOVPulse then
        local pulse        = math.sin(currentTime * 6) * (S.FOVRadius * 0.06)
        FOVCircle.Radius       = S.FOVRadius + pulse
        FOVCircle.Transparency = 0.5 + (math.sin(currentTime * 6) * 0.5)
    else
        FOVCircle.Radius       = S.FOVRadius
        FOVCircle.Transparency = 1
    end
    FOVCircle.Visible = S.Enabled and S.ShowFOV
end

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
        local screenPos    = Vector2.new(pos.X, pos.Y)
        TargetDot.Position = screenPos
        TargetDot.Visible  = true
        SnapLine.From      = UIS:GetMouseLocation()
        SnapLine.To        = screenPos
        SnapLine.Visible   = true
    else
        TargetDot.Visible = false
        SnapLine.Visible  = false
    end
end

function Drawings.HideIndicators()
    TargetDot.Visible = false
    SnapLine.Visible  = false
end

function Drawings.RefreshAccent()
    local c         = Styles.Accent
    FOVCircle.Color = c
    TargetDot.Color = c
    SnapLine.Color  = c
end

function Drawings.Cleanup()
    pcall(function() FOVCircle:Remove() end)
    pcall(function() TargetDot:Remove() end)
    pcall(function() SnapLine:Remove()  end)
end

return Drawings