-- core/state.lua
-- AimHubNext Global State & Settings
-- Mod Author: CookieLee
-- No dependencies, no require needed.

local State = {}

State.CurrentScriptID = "AimHubNext_Engine_v39"

State.LegacyIDs = {
    "TestEnvironmentGui", "TestEnv_GlobalAimSystem_v2",
    "TestEnv_GlobalAimSystem_v3", "TestEnv_GlobalAimSystem_v4",
    "TestEnv_ProUI_v5", "Ligia_Premium_UI_v6",
    "Ligia_Premium_UI_v7", "Ligia_Premium_UI_v8",
    "Ligia_Premium_UI_v8_Final", "Ligia_Premium_UI_v8_Final_v2",
    "Ligia_Premium_Engine_v9",  "Ligia_Premium_Engine_v10",
    "Ligia_Premium_Engine_v11", "Ligia_Premium_Engine_v12",
    "Ligia_Premium_Engine_v13", "Ligia_Premium_Engine_v14",
    "Ligia_Premium_Engine_v15", "Ligia_Premium_Engine_v16",
    "Ligia_Premium_Engine_v17", "Ligia_Premium_Engine_v18",
    "Ligia_Premium_Engine_v19", "Ligia_Premium_Engine_v20",
    "Ligia_Premium_Engine_v21", "Ligia_Premium_Engine_v22",
    "Ligia_Premium_Engine_v23", "Ligia_Premium_Engine_v24",
    "Ligia_Premium_Engine_v25", "Ligia_Premium_Engine_v26",
    "Ligia_Premium_Engine_v27", "Ligia_Premium_Engine_v28",
    "Ligia_Premium_Engine_v29", "Ligia_Premium_Engine_v30",
    "Ligia_Premium_Engine_v31", "Ligia_Premium_Engine_v32",
    "Ligia_Premium_Engine_v33", "Ligia_Premium_Engine_v34",
    "Ligia_Premium_Engine_v35", "Ligia_Premium_Engine_v36",
    "Ligia_Premium_Engine_v37", "Ligia_Premium_Engine_v38",
    "AimHubNext_Engine_v39",
}

State.AccentPresets = {
    Color3.fromRGB(0,   230, 115),
    Color3.fromRGB(0,   160, 255),
    Color3.fromRGB(150, 80,  255),
    Color3.fromRGB(255, 60,  100),
    Color3.fromRGB(255, 200, 0),
}

State.FireRates = {
    Normal = { press = 0.15, release = 0.15 },
    Fast   = { press = 0.06, release = 0.06 },
    Uzi    = { press = 0.01, release = 0.01 },
}

State.Settings = {
    Enabled               = true,
    WallCheck             = true,
    AutoShoot             = true,
    ESPEnabled            = true,
    ShowFOV               = true,
    FOVPulse              = true,
    TargetIndicator       = true,
    FOVCheckEnabled       = true,
    AutoSwitch            = true,
    SilentAim             = false,
    TargetPart            = "Head",
    ShootMode             = "Normal",
    Smoothness            = 15,
    FOVRadius             = 120,
    MaxDistance           = 1000,
    Prediction            = 0,
    AimMode               = "Toggle",
    TargetPriority        = "Distance",
    AimKey                = Enum.KeyCode.E,
    ToggleUiKey           = Enum.KeyCode.RightShift,
    MenuTransparency      = 0,
    BorderThickness       = 1.5,
    AccentColorIndex      = 1,
    ESPTransparency            = 0.4,
    ChamsEnabled               = true,
    ChamsVisibleColor          = Color3.fromRGB(0,   255, 100),
    ChamsOccludedColor         = Color3.fromRGB(255, 50,  50),
    ChamsVisibleTransparency   = 0.3,
    ChamsOccludedTransparency  = 0.5,
    RageEnabled           = false,
    SnapAim               = false,
    HitboxExpander        = false,
    HitboxSize            = 5,
    KillAura              = false,
    KillAuraRange         = 15,
    AutoHitbox            = "Head",
    AntiAimEnabled        = false,
    AntiAimMode           = "Spin",
    AntiAimSpeed          = 20,
    AntiAimPitch          = 0,
    ResolverEnabled       = false,
}

State.DefaultSettings = {}
for k, v in pairs(State.Settings) do
    State.DefaultSettings[k] = v
end

State.Aiming             = false
State.Target             = nil
State.LastLoggedTarget   = nil
State.LastTargetHealth   = 0
State.IsShooting         = false
State.AntiAimAngle       = 0
State.AntiAimJitterState = false
State.AntiAimSwitchTimer = 0
State.LastChamsUpdate    = 0
State.LastHitboxUpdate   = 0
State.LastKillAuraUpdate = 0
State.CHAMS_INTERVAL     = 0.2
State.HITBOX_INTERVAL    = 0.5
State.KILLAURA_INTERVAL  = 0.15
State.ChamsVisibilityCache = {}
State.OriginalSizes        = {}
State.GlobalConnections    = {}
State.UIUpdaters           = {}
State.env = (getgenv and getgenv()) or shared

return State