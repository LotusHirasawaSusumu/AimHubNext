-- core/styles.lua
-- AimHubNext Visual Style Definitions
-- Mod Author: CookieLee
-- Note: Styles.Accent is mutable at runtime when user swaps colors.
--       All UI modules should read Styles.Accent dynamically, not cache it.

local State = require(script.Parent.state)

local Styles = {}

Styles.Bg         = Color3.fromRGB(12, 13, 17)
Styles.SidebarBg  = Color3.fromRGB(16, 17, 22)
Styles.CardBg     = Color3.fromRGB(20, 21, 27)
Styles.CardHover  = Color3.fromRGB(28, 29, 36)
Styles.Border     = Color3.fromRGB(35, 37, 45)
Styles.TextMain   = Color3.fromRGB(255, 255, 255)
Styles.TextDark   = Color3.fromRGB(160, 165, 180)

-- Accent is initialized from Settings, can be changed at runtime
Styles.Accent = State.AccentPresets[State.Settings.AccentColorIndex]
            or State.AccentPresets[1]

-- Call this after user swaps accent color index in Settings
function Styles.RefreshAccent()
    Styles.Accent = State.AccentPresets[State.Settings.AccentColorIndex]
                 or State.AccentPresets[1]
end

return Styles