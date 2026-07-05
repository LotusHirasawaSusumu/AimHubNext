-- core/styles.lua
-- AimHubNext Visual Style Definitions
-- Mod Author: CookieLee

local require  = ...
local State    = require("core/state.lua")

local Styles = {}

Styles.Bg        = Color3.fromRGB(12,  13,  17)
Styles.SidebarBg = Color3.fromRGB(16,  17,  22)
Styles.CardBg    = Color3.fromRGB(20,  21,  27)
Styles.CardHover = Color3.fromRGB(28,  29,  36)
Styles.Border    = Color3.fromRGB(35,  37,  45)
Styles.TextMain  = Color3.fromRGB(255, 255, 255)
Styles.TextDark  = Color3.fromRGB(160, 165, 180)
Styles.Accent    = State.AccentPresets[State.Settings.AccentColorIndex]
                or State.AccentPresets[1]

function Styles.RefreshAccent()
    Styles.Accent = State.AccentPresets[State.Settings.AccentColorIndex]
                 or State.AccentPresets[1]
end

return Styles